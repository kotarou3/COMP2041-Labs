from email.utils import parseaddr
from email.mime.text import MIMEText
import smtplib

_emailServer = "<email server (must support STARTTLS)>"
_emailAddr = "<email username>"
_emailUsername = _emailAddr
_emailPassword = "<email password>"

def sendEmail(to, subject, message):
    msg = MIMEText(message.encode("utf8"))
    msg["Subject"] = subject.encode("utf8")
    msg["From"] = _emailAddr.encode("utf8")
    msg["To"] = to.encode("utf8")

    smtp = smtplib.SMTP(_emailServer, 587)
    smtp.ehlo()
    smtp.starttls()
    smtp.login(_emailUsername, _emailPassword)
    smtp.sendmail(_emailAddr, [to], msg.as_string())
    smtp.close()

def validateEmail(email):
    email = parseaddr(email)[1]
    if not "@" in email:
        raise ValueError

    return email
