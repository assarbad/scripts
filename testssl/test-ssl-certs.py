#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 expandtab:
__author__ = "Oliver Schneider"
__copyright__ = "Placed in the Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "0.2"
__doc__ = """
================
 test-ssl-certs
================

This script allows you to check SSL certificates of a number of hosts by
connecting to these hosts and verifying the expiry date of the SSL certificates.
"""
import os, sys

# Checking for compatibility with Python version
if (sys.version_info < (3,6)):
    sys.exit("This script requires Python version 3.6 or better.")

# Don't create .pyc or .pyo files
sys.dont_write_bytecode = True
# If we have modules stored relative to this script path
# sys.path.append(os.path.dirname(os.path.realpath(__file__)))

import argparse
import collections
import contextlib
import datetime
import email
import smtplib
import socket
import subprocess
try:
    from ConfigParser import RawConfigParser
except ImportError:
    from configparser import RawConfigParser
import OpenSSL
from collections import namedtuple, OrderedDict
from contextlib import closing, suppress
from email.message import Message
from smtplib import SMTP, SMTPRecipientsRefused, SMTPHeloError, SMTPSenderRefused, SMTPDataError
assert tuple(int(x, 10) for x in OpenSSL.version.__version__.split(".")) >= (17,5, 0), "Version of pyOpenSSL too low."

MailSettings = namedtuple("MailSettings", ["server", "msg_from", "msg_to", "subject", "sendon", "gpgrcpt", "gpgexe", "soondays"])

def prettydate(inp):
    assert len(inp) == 14
    return "%s-%s-%s %s:%s:%s" % (inp[0:4], inp[4:6], inp[6:8], inp[8:10], inp[10:12], inp[12:14])

class SslCertificate:
    __cert = None
    __validFrom = None
    __validTo = None
    __CN = None
    __certstr = None
    __SANs = []
    __hasMatchingSAN = None # intentional, as opposed to False which may be set

    class TLSConnection:
        __hostname = None
        __port = None
        __peername = None
        __cert = None

        def __init__(self, hostname, port):
            from OpenSSL.SSL import Context, Connection, OP_NO_SSLv2, OP_NO_SSLv3
            from OpenSSL.SSL import TLSv1_METHOD, TLSv1_1_METHOD, TLSv1_2_METHOD
            from select import select
            try_methods = (TLSv1_2_METHOD, TLSv1_1_METHOD, TLSv1_METHOD,) # newest first
            fallback_on_exceptions = {('SSL routines', 'ssl_choose_client_version', 'wrong ssl version',), ('SSL routines', 'state_machine', 'internal error',),}
            methods = {TLSv1_2_METHOD: "TLSv1.2", TLSv1_1_METHOD: "TLSv1.1", TLSv1_METHOD: "TLSv1"}

            self.__hostname = hostname
            self.__port = port

            run = 0

            for method in try_methods:
                state = []
                try:
                    run += 1
                    client_sock = socket.socket()
                    client_sock.connect((hostname, port, ))
                    # ssl_ctx.set_options(OP_NO_SSLv2 | OP_NO_SSLv3)
                    with closing(Connection(Context(method), client_sock)) as tls_client:
                        try:
                            # Establish connection
                            tls_client.set_connect_state()
                            state.append("[{}:{}][{}] set_connect_state -> [{}, {}]".format(hostname, port, run, methods[method], tls_client.get_state_string()))
                            # SNI (send hostname indication)
                            shostname = hostname.encode("ascii")
                            tls_client.set_tlsext_host_name(shostname)
                            state.append("[{}:{}][{}] set_tlsext_host_name -> [{}, {}]".format(hostname, port, run, methods[method], tls_client.get_state_string()))
                            tls_client.do_handshake()
                            state.append("[{}:{}][{}] do_handshake -> [{}, {}]".format(hostname, port, run, methods[method], tls_client.get_state_string()))
                            assert tls_client.get_servername() == shostname, \
                                "Hostname and servername don't match: %r vs. %r" % (tls_client.get_servername(), shostname)
                            #if method in {TLSv1_2_METHOD, TLSv1_1_METHOD}:
                            tls_client.set_connect_state()
                            state.append("[{}:{}][{}] set_connect_state -> [{}, {}]".format(hostname, port, run, methods[method], tls_client.get_state_string()))
                            self.__peername = tls_client.getpeername()
                            state.append("[{}:{}][{}] getpeername() -> [{}, {}]".format(hostname, port, run, methods[method], tls_client.get_state_string()))
                            self.__cert = tls_client.get_peer_certificate()
                            state.append("[{}:{}][{}] get_peer_certificate() -> [{}, {}]".format(hostname, port, run, methods[method], tls_client.get_state_string()))
                        finally:
                            with suppress(OpenSSL.SSL.Error):
                                tls_client.shutdown()
                            with suppress(OSError): # e.g. bad file descriptor
                                tls_client.sock_shutdown(socket.SHUT_RDWR)
                            with suppress(OpenSSL.SSL.Error):
                                tls_client.close()
                            with suppress(OSError):
                                client_sock.shutdown(socket.SHUT_RDWR)
                except Exception as e:
                    for line in state:
                        print(line, file=sys.stderr)
                    print("Uncaught in run {} [{}]: ".format(run, methods[method]), e, file=sys.stderr)
                    with suppress(OSError):
                        client_sock.shutdown(socket.SHUT_RDWR)
                    continue
                if self.__cert and self.__peername:
                    break

        def close(self):
            pass # dummy

        def get_peer_certificate(self):
            return self.__cert

    def __init__(self, hostname, port):
        with closing(SslCertificate.TLSConnection(hostname, port)) as connection:
            cert = connection.get_peer_certificate()
            assert cert is not None, "Could not get valid peer certificate {}:{}".format(hostname, port)
            self.__validFrom = cert.get_notBefore().decode("ascii")
            self.__validTo = cert.get_notAfter().decode("ascii")
            sn = {x.decode("ascii"): y.decode("ascii") for x, y in cert.get_subject().get_components()}
            sans = [str(cert.get_extension(i)) for i in range(cert.get_extension_count()) if cert.get_extension(i).get_short_name() == b"subjectAltName"]
            assert len(sans) == 1
            self.__SANs = [x.strip() for x in sans[0].split(",")]
            assert "CN" in sn
            self.__CN = sn["CN"]
            if len(self.__SANs):
                if self.__CN == hostname:
                    self.__hasMatchingSAN = True
                else:
                    self.__hasMatchingSAN =  "DNS:%s" % (hostname) in self.__SANs
            self.__cert = cert
            self.__certstr = str(cert)

    def getCN(self):
        return self.__CN

    def getValidFrom(self):
        return self.__validFrom

    def getValidTo(self):
        return self.__validTo

    def hasMatchingSAN(self):
        return self.__hasMatchingSAN

    def getSANs(self):
        return self.__SANs

class ResultCollector(object):
    def __init__(self, inifile):
        self.__inifile = inifile
        self.__warnings = []
        self.__errors = []
        self.__certs = OrderedDict()
        self.__rpt = Message()
        self.__expired = []
        self.__soonexpires = []
        self.__mailsettings = None
        self.__soonest = None

    def add_exception(self, hostname, port, text, exc):
        self.__errors.append((hostname, port, "%s\n%s" % (text, exc), ))

    def add_error(self, hostname, port, text):
        self.__errors.append((hostname, port, text, ))

    def add_warning(self, hostname, port, text):
        self.__warnings.append((hostname, port, text, ))

    def set_soonest(self, soonest):
        self.__soonest = soonest

    @property
    def errors(self):
        return self.__errors

    @property
    def warnings(self):
        return self.__warnings

    def add_certlist(self, certs):
        self.__certs = certs

    def add_expired(self, hostname, port):
        self.__expired.append((hostname, port,))

    def add_soonexpires(self, hostname, port):
        self.__soonexpires.append((hostname, port,))

    def __verify_email_settings(self):
        inifile = self.__inifile
        assert inifile is not None
        try:
            ms = dict(inifile.items("mail"))
            server = ms.get("server", "localhost")
            msg_to= ms.get("to", None)
            msg_from = ms.get("from", None)
            subject = ms.get("subject", "[SSL-CERTS] {errcnt} error(s), {wrncnt} warning(s) ({soonexpiry} expire(s) soon, {expired} expired)")
            soondays = int(ms.get("soondays", 7))
            sendon = int(ms.get("send_on", 2))
            gpgrcpt = ms.get("gpg_recipient", None)
            gpgexe = ms.get("gpg_binary", "/usr/bin/gpg")
            assert msg_from is not None
            assert msg_to is not None
            assert subject is not None
            return MailSettings(server, msg_from, msg_to, subject, sendon, gpgrcpt, gpgexe, soondays)
        except BaseException as e:
            return MailSettings(None, None, None, None, None, None, None, None)

    def verify_email_settings(self):
        if self.__mailsettings is None:
            self.__mailsettings = self.__verify_email_settings()
        return self.__mailsettings

    def report(self):
        msg = self.__rpt
        assert msg is not None
        err, wrn, exp, soon, certs, soonest = self.__errors, self.__warnings, self.__expired, self.__soonexpires, self.__certs, self.__soonest
        assert isinstance(soonest, tuple) and len(soonest) > 1
        ms = self.verify_email_settings()
        soonestDT = datetime.datetime.strptime(soonest[0][:-1], "%Y%m%d%H%M%S").replace(tzinfo=None)
        now = datetime.datetime.utcnow()
        delta = soonestDT - now
        msg["To"] = ms.msg_to or "<unknown@localhost>"
        msg["From"] = ms.msg_from.format(fqdn=socket.getfqdn()) or "<unknown@localhost>"
        msg["Subject"] = ms.subject.format(errcnt=len(err), wrncnt=len(wrn), soonexpiry=len(soon), expired=len(exp), soonest=prettydate(soonest[0]), soonest_delta=delta)
        lines = []
        lines.append("[%s] Checked %d hosts for their SSL certificates. %d warning(s) and %d error(s). Soonest to expire is %s at %s (%s).\n" % (now, len(certs), len(wrn), len(err), soonest[1], prettydate(soonest[0]), delta))
        if len(soon):
            lines.append("SOON TO EXPIRE CERTIFICATES (%d):\n" % (len(soon)))
            for hostname, port in soon:
                lines.append("  * %s:%d" % (hostname, port))
            lines.append("\n")
        if len(exp):
            lines.append("EXPIRED CERTIFICATES (%d):\n" % (len(exp)))
            for hostname, port in exp:
                lines.append("  * %s:%d" % (hostname, port))
            lines.append("\n")
        if len(err):
            lines.append("ERRORS (%d):\n" % (len(err)))
            for hostname, port, text in err:
                lines.append("  * %s:%d:\n    %s" % (hostname, port, text.format(hostname=hostname, port=port)))
            lines.append("\n")
        if len(wrn):
            lines.append("WARNINGS (%d):\n" % (len(wrn)))
            for hostname, port, text in wrn:
                lines.append("  * %s:%d:\n    %s" % (hostname, port, text.format(hostname=hostname, port=port)))
            lines.append("\n")
        lines.append("CHECKED HOSTS (%d), SOONEST TO EXPIRE FIRST:\n" % (len(certs)))
        certexpiry = {}
        certinvalid = []
        for host, cert in certs.items():
            if cert is None:
                certinvalid.append(host)
            else:
                tmptpl = (cert.getValidTo()[:14], cert.getValidFrom()[:14],)
                if tmptpl not in certexpiry:
                    certexpiry[tmptpl] = []
                certexpiry[tmptpl].append(host)
                #lines.append("  * %s:%d -> %s until %s" % (host[0], host[1], cert.getValidFrom()[:14], cert.getValidTo()[:14]))
        for tod, fromd in sorted(certexpiry.keys()):
            lines.append("  * Valid from %s through %s" % (prettydate(fromd), prettydate(tod)))
            for host in certexpiry[(tod, fromd,)]:
                lines.append("    -> %s:%d" % (host[0], host[1]))
        if len(certinvalid):
            for host in certinvalid:
                lines.append("  * %s:%d -> invalid certificate or other error" % (host[0], host[1]))
        msg.set_payload("\n".join(lines))
        return msg

    def sendreport(self):
        ms = self.verify_email_settings()
        msg = self.report()
        errors = None
        print(msg.as_string())
        if ms.gpgexe and ms.gpgrcpt:
            from subprocess import Popen, PIPE, STDOUT
            args = [ms.gpgexe.strip(), "--batch", "--no-tty", "--yes", "-ear", ms.gpgrcpt.strip(), "--", "-"]
            with Popen(args, stdin=PIPE, stdout=PIPE, stderr=PIPE, bufsize=0) as emsg:
                newmsg, errors = emsg.communicate(msg.get_payload().encode("utf-8"))
                if emsg.returncode in {0}:
                    msg.set_payload(newmsg)
                else:
                    msg.set_payload(errors)
        try:
            smtp = SMTP('localhost')
            smtp.sendmail(msg['From'], msg['To'], msg.as_string())
            if errors is not None:
                print(errors.decode("ascii"), file=sys.stderr)
                return 1
        except (SMTPRecipientsRefused, SMTPHeloError, SMTPSenderRefused, SMTPDataError) as e:
            print(repr(e), file=sys.stderr)
            return 2
        finally:
            smtp.quit()
        return 0

class CertificateExpiryTimes(object):
    def __init__(self, inifile):
        self.__inifile = inifile
        cfg = RawConfigParser()
        cfg.read(inifile)
        self.__cfg = cfg

    def runcheck(self):
        cfg = self.__cfg
        assert cfg.has_section("hosts")
        assert cfg.has_section("mail")
        res = ResultCollector(self.__cfg)
        ms = res.verify_email_settings()
        soondays = ms.soondays or 7
        certs = OrderedDict()
        soonest = ("99991231235959", "localhost",)
        for hostname in cfg.options("hosts"):
            try:
                ports = tuple([cfg.getint("hosts", hostname)])
            except ValueError:
                ports = tuple(sorted(set([int(x.strip()) for x in cfg.get("hosts", hostname).split(",")])))
            for port in ports:
                try:
                    cert = SslCertificate(hostname, port)
                    if not cert.hasMatchingSAN():
                        res.add_warning(hostname, port, "No matching Subject Alternative Name, but also not the Common Name for {hostname}:{port}.")
                    validto = datetime.datetime.strptime(cert.getValidTo()[:-1], "%Y%m%d%H%M%S").replace(tzinfo=None)
                    if soonest[0] > cert.getValidTo()[:14]:
                        soonest = (cert.getValidTo()[:14], hostname,)
                    now = datetime.datetime.utcnow()
                    delta = validto - now
                    deltasec = delta.total_seconds()
                    if deltasec < 0:
                        res.add_error(hostname, port, "Certificate for {hostname}:{port} expired on %s (expired for %s)" % (validto, delta))
                        res.add_expired(hostname, port)
                    if deltasec > 0 and deltasec < (soondays*24*3600):
                        res.add_warning(hostname, port, "Certificate for {hostname}:{port} expires on %s (expires in %s)" % (validto, delta))
                        res.add_soonexpires(hostname, port)
                    certs[(hostname, port, )] = cert
                except socket.gaierror as e:
                    res.add_exception(hostname, port, "Failed getting address info from name for {hostname}:{port}. See output below.", e)
                    certs[(hostname, port, )] = None
                except AssertionError as e:
                    res.add_exception(hostname, port, "Assertion failed during TLS connection attempt to {hostname}:{port}. See output below.", e)
                    certs[(hostname, port, )] = None
                except OpenSSL.SSL.Error as e:
                    res.add_exception(hostname, port, "OpenSSL reported an error for {hostname}:{port}.", e)
                    certs[(hostname, port, )] = None
                except RuntimeError as e:
                    res.add_exception(hostname, port, "Unusual exception caught {hostname}:{port}.", e)
                    certs[(hostname, port, )] = None
        res.add_certlist(certs)
        res.set_soonest(soonest)
        return res

if __name__ == "__main__":
    try:
        inifile = os.path.splitext(os.path.realpath(__file__))[0] + ".ini"
        res = CertificateExpiryTimes(inifile).runcheck()
        sys.exit(res.sendreport())
    except SystemExit:
        pass
    except ImportError:
        raise # re-raise
    except RuntimeError:
        raise # re-raise
    except:
        print(__doc__)
        raise # re-raise
