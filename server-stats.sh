#!/bin/bash
ncpu=$(nproc)
BAR_WIDTH=30
LABEL_WIDTH=14

# Bar function filled with ### and --- for leftover space
function draw_bar(){
    local label=$1
    local percent=$2
    local fill 
    local empty

    fill=$(
            awk -v p="$percent" -v w="$BAR_WIDTH" 'BEGIN {
                if(p > 100) p = 100
                if(p < 0) p = 0
                printf "%d", (p / 100) * w
            }'
        )
     empty=$((BAR_WIDTH - fill))

     # Draw bar with calculated fill and empty
     printf "%-${LABEL_WIDTH}s [%s%s] %6.1f%%\n" \
         "$label" \
         "$(printf "%${fill}s" | tr ' ' '#'  )" \
         "$(printf "%${empty}s" | tr ' ' '-'  )" \
         "$percent"
}

function render_bar(){
    local percent=$1
    local fill 
    local empty

    fill=$(
            awk -v p="$percent" -v w="$BAR_WIDTH" 'BEGIN {
                if(p > 100) p = 100
                if(p < 0) p = 0
                printf "%d", (p / 100) * w
            }'
        )
     empty=$((BAR_WIDTH - fill))
     
     hashes="$(printf "%${fill}s" | tr ' ' '#'  )"
     dashes="$(printf "%${empty}s" | tr ' ' '-'  )"
     
     # Draw bar with calculated fill and empty
     printf "[%s%s]" "$hashes" "$dashes"
}


# KB to human readable
function kb2human(){
    local kb=$1

    awk -v x="$kb" 'BEGIN {
        if (x>=1024*1024) printf "%.1f GB", x/1024/1024
        else if (x >= 1024) printf "%.1f MB", x/1024
        else printf "%d KB", x
    }'
}

# CPU usage
echo "--- CPU (${ncpu} cores) ---"
read -r cpu_total <<< "$(ps aux | awk -v n="$ncpu" 'NR>1 {cpu_usage_sum += $3} END { print cpu_usage_sum/n }')"

draw_bar "Used" "${cpu_total}"
echo

# Memory usage
echo "--- Memory ---"

read -r mem_total mem_used mem_free mem_available <<< "$(free | awk '/Mem:/ {print $2, $3, $4, $7}')"
mem_used_percent=$(awk -v a="$mem_available" -v t="$mem_total" 'BEGIN { printf "%.1f", (t-a)/t*100 }')
mem_free_percent=$(awk -v a="$mem_available" -v t="$mem_total" 'BEGIN { printf "%.1f", a/t*100 }') 


printf "%-${LABEL_WIDTH}s %s\n" "Total" "$(kb2human "$mem_total")"

printf "%-${LABEL_WIDTH}s %s\n%-${LABEL_WIDTH}s %s %6.1f%%\n" "Used" "$(kb2human $(($mem_total - $mem_available)))" "" "$(render_bar "${mem_used_percent}")" "${mem_used_percent}"
printf "%-${LABEL_WIDTH}s %s\n%-${LABEL_WIDTH}s %s %6.1f%%\n" "Free" "$(kb2human $mem_available)" "" "$(render_bar "${mem_free_percent}")" "${mem_free_percent}"
echo


# Disk usage
echo "--- Disk ---"

read -r disk_total disk_used disk_free <<< "$(df / | awk 'NR == 2 {print $2, $3, $4}')"
disk_used_percent=$(awk -v u="$disk_used" -v t="$disk_total" -v f="$disk_free" 'BEGIN { printf "%.1f", u / (u+f) * 100 }')
disk_free_percent=$(awk -v u="$disk_used" -v t="$disk_total" -v f="$disk_free" 'BEGIN { printf "%.1f", f / (u+f) * 100 }')


printf "%-${LABEL_WIDTH}s %s\n" "Total" "$(kb2human $disk_total)"
printf "%-${LABEL_WIDTH}s %s\n%-${LABEL_WIDTH}s %s %6.1f%%\n" "Used" "$(kb2human $disk_used)" "" "$(render_bar "${disk_used_percent}")" "${disk_used_percent}"
printf "%-${LABEL_WIDTH}s %s\n%-${LABEL_WIDTH}s %s %6.1f%%\n" "Free" "$(kb2human $disk_free)" "" "$(render_bar "${disk_free_percent}")" "${disk_free_percent}"
echo

# Snapshot of ps aux for further sorting
ps_snapshot=$(ps -eo pid,%cpu,%mem,comm --no-headers)

# Top 5 process by CPU usage
echo "--- TOP 5 process by CPU usage ---"
echo
ps_by_cpu=$(echo "$ps_snapshot" | sort -k2 -nr | head -5)
printf "%-${LABEL_WIDTH}s %8s %5s %5s %s\n" "" "PID" "CPU" "MEM" "NAME"
while read -r pid cpu mem comm; do
    printf "%-${LABEL_WIDTH}s %8s %5s %5s %s\n" "" "$pid" "$cpu" "$mem" "$comm"
done <<< $ps_by_cpu 
echo

# Top 5 process by Memory usage
echo "--- TOP 5 process by Memory usage ---"
echo
ps_by_mem=$(echo "$ps_snapshot" | sort -k3 -nr | head -5)
printf "%-${LABEL_WIDTH}s %8s %5s %5s %s\n" "" "PID" "CPU" "MEM" "NAME"
while read -r pid cpu mem comm; do
    printf "%-${LABEL_WIDTH}s %8s %5s %5s %s\n" "" "$pid" "$cpu" "$mem" "$comm"
done <<< $ps_by_mem 
echo
