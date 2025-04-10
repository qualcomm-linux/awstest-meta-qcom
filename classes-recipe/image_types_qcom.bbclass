# Copyright (c) 2023-2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

inherit image_types

IMAGE_TYPES += "qcomflash"

QCOM_ESP_IMAGE ?= "esp-qcom-image"
QCOM_ESP_FILE ?= "${@'efi.bin' if d.getVar('QCOM_ESP_IMAGE') else ''}"

# There is currently no upstream-compatible way for the firmware to
# identify and load the correct DTB from a combined-dtb that contains all
# dtbs defined in KERNEL_DEVICETREE, so pick the first individual image
# generated by linux-qcom-dtbbin, unless a different one is specified.
QCOM_DTB_DEFAULT ?= "${@os.path.basename(d.getVar('KERNEL_DEVICETREE').split()[0][:-4]) if d.getVar('KERNEL_DEVICETREE') else ''}"
QCOM_DTB_FILE ?= "dtb.bin"

QCOM_BOOT_FILES_SUBDIR ?= ""

QCOM_PARTITION_CONF ?= ""

QCOM_ROOTFS_FILE ?= "rootfs.img"
IMAGE_QCOMFLASH_FS_TYPE ??= "ext4"

QCOMFLASH_DIR = "${IMGDEPLOYDIR}/${IMAGE_NAME}.qcomflash"
IMAGE_CMD:qcomflash = "create_qcomflash_pkg"
do_image_qcomflash[dirs] = "${QCOMFLASH_DIR}"
do_image_qcomflash[cleandirs] = "${QCOMFLASH_DIR}"
do_image_qcomflash[depends] += "${@ ['', '${QCOM_PARTITION_CONF}:do_deploy'][d.getVar('QCOM_PARTITION_CONF') != '']} \
                                virtual/kernel:do_deploy \
				${@'${QCOM_ESP_IMAGE}:do_image_complete' if d.getVar('QCOM_ESP_IMAGE') != '' else  ''}"
IMAGE_TYPEDEP:qcomflash += "${IMAGE_QCOMFLASH_FS_TYPE}"

create_qcomflash_pkg() {
    # esp image
    if [ -n "${QCOM_ESP_FILE}" ]; then
        install -m 0644 ${DEPLOY_DIR_IMAGE}/${QCOM_ESP_IMAGE}-${MACHINE}.rootfs.vfat ${QCOM_ESP_FILE}
    fi

    # dtb image
    if [ -n "${QCOM_DTB_DEFAULT}" ] && \
                [ -f "${DEPLOY_DIR_IMAGE}/dtb-${QCOM_DTB_DEFAULT}-image.vfat" ]; then
        # default image
        install -m 0644 ${DEPLOY_DIR_IMAGE}/dtb-${QCOM_DTB_DEFAULT}-image.vfat ${QCOM_DTB_FILE}
        # copy all images so they can be made available via the same tarball
        for dtbimg in ${DEPLOY_DIR_IMAGE}/dtb-*-image.vfat; do
            install -m 0644 ${dtbimg} .
        done
    fi

    # vmlinux
    [ -e "${DEPLOY_DIR_IMAGE}/vmlinux" -a \
        ! -e "vmlinux" ] && \
        install -m 0644 "${DEPLOY_DIR_IMAGE}/vmlinux" vmlinux

    # Legacy boot images
    if [ -n "${QCOM_DTB_DEFAULT}" ]; then
        [ -e "${DEPLOY_DIR_IMAGE}/boot-initramfs-${QCOM_DTB_DEFAULT}-${MACHINE}.img" -a \
            ! -e "boot.img" ] && \
            install -m 0644 "${DEPLOY_DIR_IMAGE}/boot-initramfs-${QCOM_DTB_DEFAULT}-${MACHINE}.img" boot.img
        [ -e "${DEPLOY_DIR_IMAGE}/boot-${QCOM_DTB_DEFAULT}-${MACHINE}.img" -a \
            ! -e "boot.img" ] && \
            install -m 0644 "${DEPLOY_DIR_IMAGE}/boot-${QCOM_DTB_DEFAULT}-${MACHINE}.img" boot.img
    fi
    [ -e "${DEPLOY_DIR_IMAGE}/boot-${MACHINE}.img" -a \
        ! -e "boot.img" ] && \
        install -m 0644 "${DEPLOY_DIR_IMAGE}/boot-${MACHINE}.img" boot.img

    # rootfs image
    install -m 0644 ${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.${IMAGE_QCOMFLASH_FS_TYPE} ${QCOM_ROOTFS_FILE}

    # partition bins
    for pbin in `find ${DEPLOY_DIR_IMAGE}/${QCOM_BOOT_FILES_SUBDIR} -maxdepth 1 -type f -name 'gpt_main*.bin' \
                -o -name 'gpt_backup*.bin' -o -name 'patch*.xml'`; do
        install -m 0644 ${pbin} .
    done

    # skip BLANK_GPT and WIPE_PARTITIONS for rawprogram xml files
    for rawpg in `find ${DEPLOY_DIR_IMAGE}/${QCOM_BOOT_FILES_SUBDIR} -maxdepth 1 -type f -name 'rawprogram*.xml' \
                ! -name 'rawprogram*_BLANK_GPT.xml' ! -name 'rawprogram*_WIPE_PARTITIONS.xml'`; do
        install -m 0644 ${rawpg} .
    done

    if [ -n "${QCOM_CDT_FILE}" ]; then
        install -m 0644 ${DEPLOY_DIR_IMAGE}/${QCOM_BOOT_FILES_SUBDIR}/${QCOM_CDT_FILE}.bin cdt.bin
        # For machines with a published cdt file, let's make sure we flash it
        sed -i '/label="cdt"/ s/filename=""/filename="cdt.bin"/' rawprogram*.xml
    fi

    for logfs in `find ${DEPLOY_DIR_IMAGE}/${QCOM_BOOT_FILES_SUBDIR} -maxdepth 1 -type f -name 'logfs_*.bin'`; do
        install -m 0644 ${logfs} .
    done
    for zeros in `find ${DEPLOY_DIR_IMAGE}/${QCOM_BOOT_FILES_SUBDIR} -maxdepth 1 -type f -name 'zeros_*.bin'`; do
        install -m 0644 ${zeros} .
    done

    # boot firmware
    for bfw in `find ${DEPLOY_DIR_IMAGE}/${QCOM_BOOT_FILES_SUBDIR} -maxdepth 1 -type f -name '*.elf' -o -name '*.mbn' -o -name '*.fv'`; do
        install -m 0644 ${bfw} .
    done

    # Create symlink to ${QCOMFLASH_DIR} dir
    ln -rsf ${QCOMFLASH_DIR} ${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.qcomflash

    # Create qcomflash tarball
    ${IMAGE_CMD_TAR} --sparse --numeric-owner --transform="s,^\./,${IMAGE_BASENAME}-${MACHINE}/," -cf- . | gzip -f -9 -n -c --rsyncable > ${IMGDEPLOYDIR}/${IMAGE_NAME}.qcomflash.tar.gz
    ln -sf ${IMAGE_NAME}.qcomflash.tar.gz ${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.qcomflash.tar.gz
}

create_qcomflash_pkg[vardepsexclude] += "DATETIME"
