#!/usr/bin/env bash
# Temperatures and fans feed: one JSON line every 2.5 s while it runs (the widget starts it only while it is visible).
# Sensors are detected once from /sys/class/hwmon (CPU: coretemp / k10temp; GPU: amdgpu / i915 / xe / nouveau, or nvidia-smi;
# SSD: nvme; fans: every fan*_input). A sensor that does not exist is simply absent from the output - never a made-up value.
export LC_ALL=C
SYS="${WD_SYSFS:-/sys}"                                      # test hook: point at a fake sysfs tree
shopt -s nullglob
WARN="${1:-80}"; [[ "$WARN" =~ ^[0-9]+$ ]] || WARN=80       # usage: thermals.sh [warn-temperature-C]  (the widget's "warn_c" prop)

CPU=""; GPU=""; declare -a SSD=() FANF=() FANL=() FANMAX=()
pick_label() {   # pick_label <hwmon dir> <label regex> -> path of the matching temp*_input
    local f l
    for f in "$1"/temp*_input; do
        l=$(<"${f%_input}_label" 2>/dev/null) || l=""
        [[ "$l" =~ $2 ]] && { echo "$f"; return; }
    done
}
for h in "$SYS"/class/hwmon/hwmon*; do
    n=$(<"$h/name")
    case "$n" in
        coretemp)  [ -z "$CPU" ] && CPU=$(pick_label "$h" '^Package') ;;
        k10temp)   [ -z "$CPU" ] && CPU=$(pick_label "$h" '^(Tctl|Tdie)$') ;;
        amdgpu|i915|xe|nouveau) [ -z "$GPU" ] && { GPU=$(pick_label "$h" '^(edge|junction|GPU)'); [ -z "$GPU" ] && GPU=$(ls "$h"/temp1_input 2>/dev/null | head -n1); } ;;
        nvme)      f=$(pick_label "$h" '^Composite$'); [ -z "$f" ] && f="$h/temp1_input"; [ -r "$f" ] && SSD+=("$f") ;;
    esac
    for f in "$h"/fan*_input; do
        i=${f##*fan}; i=${i%_input}
        l="Lüfter $i"; [ -r "${f%_input}_label" ] && l=$(<"${f%_input}_label")
        [ "$n" = amdgpu ] && l="GPU-Lüfter"
        FANF+=("$f"); FANL+=("$l"); FANMAX+=(0)
    done
done
# CPU fallback: the package thermal zone
if [ -z "$CPU" ]; then
    for z in "$SYS"/class/thermal/thermal_zone*; do
        [[ "$(<"$z/type")" =~ ^(x86_pkg_temp|cpu_thermal|k10temp)$ ]] && { CPU="$z/temp"; break; }
    done
fi
NVSMI=""; [ -z "$GPU" ] && command -v nvidia-smi >/dev/null 2>&1 && NVSMI=1

rd() { local v; read -r v < "$1" 2>/dev/null && [[ "$v" =~ ^-?[0-9]+$ ]] && echo $(( v / 1000 )) || echo null; }

while true; do
    C=null; G=null; S=""; F=""
    [ -n "$CPU" ] && C=$(rd "$CPU")
    [ -n "$GPU" ] && G=$(rd "$GPU")
    [ -n "$NVSMI" ] && { v=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1); [[ "$v" =~ ^[0-9]+$ ]] && G=$v; }
    for f in "${SSD[@]}"; do S+="$(rd "$f"),"; done
    for i in "${!FANF[@]}"; do
        read -r v < "${FANF[$i]}" 2>/dev/null; [[ "$v" =~ ^[0-9]+$ ]] || continue
        [ "$v" -gt "${FANMAX[$i]}" ] && FANMAX[$i]=$v
        # a fan that never turned in this session is not wired / not reported: leave it out instead of showing 0 rpm
        [ "${FANMAX[$i]}" -gt 0 ] && F+="{\"label\":\"${FANL[$i]}\",\"rpm\":$v},"
    done
    printf '{"warn":%s,"cpu":%s,"gpu":%s,"ssd":[%s],"fans":[%s]}\n' "$WARN" "$C" "$G" "${S%,}" "${F%,}"
    sleep 2.5
done
