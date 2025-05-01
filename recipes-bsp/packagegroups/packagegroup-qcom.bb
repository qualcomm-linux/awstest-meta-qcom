SUMMARY = "Extra userspace packages for QCOM platforms"

inherit packagegroup

PACKAGES = " \
    ${PN}-boot-essential \
    ${PN}-boot-additional \
"

RDEPENDS:${PN}-boot-essential = " \
    pd-mapper \
    qrtr \
    rmtfs \
    tqftpserv \
"

RDEPENDS:${PN}-boot-additional = " \
    fastrpc \
"
