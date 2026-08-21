#!/usr/bin/env bash

# Shared, read-only hardware collection for KiyArch live commands.
# Callers may source this file with nounset enabled.

kiyarch_have() { command -v "$1" >/dev/null 2>&1; }

kiyarch_read_value() {
    local path="$1" value=""
    if [[ -r "$path" ]]; then IFS= read -r value < "$path" || true; fi
    printf '%s' "$value"
}

kiyarch_first_nonempty() {
    local value
    for value in "$@"; do
        if [[ -n "$value" && "$value" != None && "$value" != unknown ]]; then
            printf '%s' "$value"
            return
        fi
    done
}

kiyarch_json_escape() {
    local input="$1" output="" character ordinal index
    for ((index=0; index<${#input}; index++)); do
        character="${input:index:1}"
        case "$character" in
            '\\') output+='\\\\' ;;
            '"') output+='\\"' ;;
            $'\n') output+='\\n' ;;
            $'\r') output+='\\r' ;;
            $'\t') output+='\\t' ;;
            *)
                printf -v ordinal '%d' "'${character}"
                if ((ordinal < 32)); then printf -v character '\\u%04x' "$ordinal"; fi
                output+="$character"
                ;;
        esac
    done
    printf '%s' "$output"
}

kiyarch_json_string() { printf '"%s"' "$(kiyarch_json_escape "$1")"; }

kiyarch_json_array_strings() {
    local first=1 value
    printf '['
    for value in "$@"; do
        ((first)) || printf ','
        first=0
        kiyarch_json_string "$value"
    done
    printf ']'
}

kiyarch_json_bool() {
    [[ "$1" == yes || "$1" == true || "$1" == 1 ]] && printf true || printf false
}

kiyarch_format_bytes() {
    local bytes="$1"
    if [[ ! "$bytes" =~ ^[0-9]+$ ]]; then
        printf 'unknown'
    elif ((bytes >= 1099511627776)); then
        printf '%d TiB' $((bytes / 1099511627776))
    elif ((bytes >= 1073741824)); then
        printf '%d GiB' $((bytes / 1073741824))
    elif ((bytes >= 1048576)); then
        printf '%d MiB' $((bytes / 1048576))
    elif ((bytes >= 1024)); then
        printf '%d KiB' $((bytes / 1024))
    else
        printf '%d B' "$bytes"
    fi
}

kiyarch_collect_platform() {
    KIYARCH_ARCH="$(uname -m 2>/dev/null || printf unknown)"
    [[ -d /sys/firmware/efi ]] && KIYARCH_FIRMWARE=uefi || KIYARCH_FIRMWARE=legacy_bios
}

kiyarch_lsblk_field() {
    local field="$1" record="$2" expression
    expression="${field}=\"([^\"]*)\""
    [[ "$record" =~ $expression ]] && printf '%s' "${BASH_REMATCH[1]}"
}

kiyarch_lsblk_has_field() {
    local field="$1" record="$2"
    [[ "$record" =~ (^|[[:space:]])${field}=\" ]]
}

kiyarch_collect_storage() {
    local record device type transport size model rota removable read_only pttype serial wwn name
    local device_link storage_class media removable_flag metadata_state

    STORAGE_DEVICE=(); STORAGE_SIZE=(); STORAGE_SIZE_BYTES=(); STORAGE_MODEL=()
    STORAGE_TRANSPORT=(); STORAGE_CLASS=(); STORAGE_MEDIA=(); STORAGE_REMOVABLE=()
    STORAGE_READONLY=(); STORAGE_PTTYPE=(); STORAGE_SERIAL=(); STORAGE_WWN=(); STORAGE_METADATA=(); STORAGE_WARNINGS=()

    kiyarch_have lsblk || return 0
    while IFS= read -r record; do
        [[ -n "$record" ]] || continue
        device="$(kiyarch_lsblk_field PATH "$record")"
        type="$(kiyarch_lsblk_field TYPE "$record")"
        transport="$(kiyarch_lsblk_field TRAN "$record")"
        size="$(kiyarch_lsblk_field SIZE "$record")"
        model="$(kiyarch_lsblk_field MODEL "$record")"
        rota="$(kiyarch_lsblk_field ROTA "$record")"
        removable="$(kiyarch_lsblk_field RM "$record")"
        read_only="$(kiyarch_lsblk_field RO "$record")"
        pttype="$(kiyarch_lsblk_field PTTYPE "$record")"
        name="$(basename "$device")"
        [[ "$type" == disk && "$name" != zram* && -e "/sys/class/block/$name/device" && -n "$device" ]] || continue

        # lsblk often leaves TRAN empty for virtio devices. Infer only from
        # the kernel device path; unknown values remain visible and unsafe.
        device_link="$(readlink -f "/sys/class/block/$name/device" 2>/dev/null || true)"
        if [[ -z "$transport" ]]; then
            case "$device_link" in
                *virtio*) transport=virtio ;;
                *nvme*) transport=nvme ;;
                *usb*) transport=usb ;;
                *ata*|*ahci*) transport=sata ;;
            esac
        fi
        transport="${transport:-unknown}"
        model="${model:-unknown}"
        kiyarch_lsblk_has_field PTTYPE "$record" && pttype="${pttype:-none}" || pttype=unknown
        media=unknown
        [[ "$rota" == 1 ]] && media=rotational
        [[ "$rota" == 0 ]] && media=solid_state
        removable_flag=unknown
        [[ "$removable" == 0 ]] && removable_flag=no
        [[ "$removable" == 1 || "$transport" == usb ]] && removable_flag=yes

        storage_class=other
        case "$transport" in
            nvme) storage_class=nvme ;;
            sata|ata) storage_class=sata ;;
            usb) storage_class=usb ;;
            virtio) storage_class=virtio ;;
        esac

        metadata_state=complete
        if ! kiyarch_lsblk_has_field PATH "$record" || ! kiyarch_lsblk_has_field TYPE "$record" ||
              ! kiyarch_lsblk_has_field TRAN "$record" || ! kiyarch_lsblk_has_field SIZE "$record" ||
              ! kiyarch_lsblk_has_field ROTA "$record" || ! kiyarch_lsblk_has_field RM "$record" ||
              ! kiyarch_lsblk_has_field RO "$record" || ! kiyarch_lsblk_has_field PTTYPE "$record" ||
              ! [[ "$size" =~ ^[0-9]+$ ]] ||
              [[ "$size" == 0 || "$transport" == unknown || "$pttype" == unknown ]] ||
              ! [[ "$rota" =~ ^[01]$ ]] || ! [[ "$removable" =~ ^[01]$ ]] || ! [[ "$read_only" =~ ^[01]$ ]]; then
            metadata_state=ambiguous
        fi
        if [[ "$model" == unknown ]]; then
            STORAGE_WARNINGS+=("$device: model metadata is unavailable; verify the device identity manually.")
        fi
        [[ "$transport" == unknown ]] && STORAGE_WARNINGS+=("$device: transport metadata is unavailable; target selection is unsafe.")
        [[ "$metadata_state" == ambiguous ]] && STORAGE_WARNINGS+=("$device: required disk metadata is incomplete; it cannot be selected.")
        case "$pttype" in
            dos) STORAGE_WARNINGS+=("$device: an existing MBR partition table is unsupported by this UEFI/GPT planner milestone.") ;;
            unknown) STORAGE_WARNINGS+=("$device: partition-table metadata is unavailable; target selection is unsafe.") ;;
        esac
        [[ "$removable_flag" == yes ]] && STORAGE_WARNINGS+=("$device: removable media detected; selecting it can destroy removable media contents.")
        [[ "$read_only" == 1 ]] && STORAGE_WARNINGS+=("$device: disk is read-only and cannot be used as an installation target.")

        STORAGE_DEVICE+=("$device")
        STORAGE_SIZE+=("$(kiyarch_format_bytes "$size")")
        STORAGE_SIZE_BYTES+=("$size")
        STORAGE_MODEL+=("$model")
        STORAGE_TRANSPORT+=("$transport")
        STORAGE_CLASS+=("$storage_class")
        STORAGE_MEDIA+=("$media")
        STORAGE_REMOVABLE+=("$removable_flag")
        STORAGE_READONLY+=("$read_only")
        STORAGE_PTTYPE+=("$pttype")
        STORAGE_METADATA+=("$metadata_state")
        serial="$(kiyarch_lsblk_field SERIAL "$record")"; wwn="$(kiyarch_lsblk_field WWN "$record")"
        STORAGE_SERIAL+=("${serial:-unknown}"); STORAGE_WWN+=("${wwn:-unknown}")
    done < <(lsblk -dnP -b -o PATH,TYPE,TRAN,SIZE,MODEL,ROTA,RM,RO,PTTYPE,SERIAL,WWN 2>/dev/null)
}

kiyarch_storage_json_item() {
    local index="$1" removable=false readonly=false candidate=false
    [[ "${STORAGE_REMOVABLE[$index]}" == yes ]] && removable=true
    [[ "${STORAGE_READONLY[$index]}" == 1 ]] && readonly=true
    [[ "${STORAGE_METADATA[$index]}" == complete && "$readonly" == false ]] && candidate=true
    local rotational=false
    [[ "${STORAGE_MEDIA[$index]}" == rotational ]] && rotational=true
    printf '{"device":%s,"size":%s,"size_bytes":%s,"model":%s,"transport":%s,"storage_class":%s,"media":%s,"rotational":%s,"removable":%s,"readonly":%s,"partition_table":%s,"serial":%s,"wwn":%s,"metadata":%s,"install_target_candidate":%s}' \
        "$(kiyarch_json_string "${STORAGE_DEVICE[$index]}")" \
        "$(kiyarch_json_string "${STORAGE_SIZE[$index]}")" \
        "${STORAGE_SIZE_BYTES[$index]:-null}" \
        "$(kiyarch_json_string "${STORAGE_MODEL[$index]}")" \
        "$(kiyarch_json_string "${STORAGE_TRANSPORT[$index]}")" \
        "$(kiyarch_json_string "${STORAGE_CLASS[$index]}")" \
        "$(kiyarch_json_string "${STORAGE_MEDIA[$index]}")" "$rotational" \
        "$removable" "$readonly" "$(kiyarch_json_string "${STORAGE_PTTYPE[$index]}")" "$(kiyarch_json_string "${STORAGE_SERIAL[$index]:-unknown}")" "$(kiyarch_json_string "${STORAGE_WWN[$index]:-unknown}")" \
        "$(kiyarch_json_string "${STORAGE_METADATA[$index]}")" "$candidate"
}
