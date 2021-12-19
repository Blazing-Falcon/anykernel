#!/system/bin/sh

# zram writeback
resetprop ro.zram.mark_idle_delay_mins 60
resetprop ro.zram.first_wb_delay_mins 180
resetprop ro.zram.periodic_wb_delay_hours 24

# write function taken from ktweak
write() {
	# Bail out if file does not exist
	[[ ! -f "$1" ]] && return 1

	# Make file writable in case it is not already
	chmod +w "$1" 2> /dev/null

	# Write the new value and bail if there's an error
	if ! echo "$2" > "$1" 2> /dev/null
	then
		echo "Failed: $1 → $2"
		return 1
	fi

	# Log the success
	echo "$1 → $2"
}

# sleep for 1m to avoid being overridden
sleep 1m

# task turbo
write /sys/module/task_turbo/parameters/feats 15

# stune stuff
write /dev/stune/schedtune.boost 6
write /dev/stune/foreground/schedtune.boost 8
write /dev/stune/top-app/schedtune.boost 12

# vm and mm stuff
write /proc/sys/vm/dirty_ratio 30
write /proc/sys/vm/dirty_background_ratio 10
write /proc/sys/vm/dirty_expire_centisecs 3000
write /proc/sys/vm/dirty_writeback_centisecs 3000
write /proc/sys/vm/overcommit_ratio 100
write /proc/sys/vm/stat_interval 10
write /proc/sys/vm/vfs_cache_pressure 120
write /proc/sys/vm/watermark_scale_factor 30
write /proc/sys/vm/page-cluster 0
write /proc/sys/vm/swappiness 190
write /sys/kernel/mm/swap/vma_ra_enabled false

# tcp stuff
write /proc/sys/net/ipv4/tcp_ecn 1
write /proc/sys/net/ipv4/tcp_fastopen 3
write /proc/sys/net/ipv4/tcp_syncookies 0

# io stuff
for queue in /sys/block/*/queue
do
	# Choose the first governor available
	avail_scheds="$(cat "$queue/scheduler")"
	for sched in cfq noop kyber bfq mq-deadline none
	do
		if [[ "$avail_scheds" == *"$sched"* ]]
		then
			write "$queue/scheduler" "$sched"
			break
		fi
	done

	# Do not use I/O as a source of randomness
	write "$queue/add_random" 0

	# Disable I/O statistics accounting
	write "$queue/iostats" 0

	# Reduce heuristic read-ahead in exchange for I/O latency
	write "$queue/read_ahead_kb" 256

	# Reduce the maximum number of I/O requests in exchange for latency
	write "$queue/nr_requests" 256
done

# misc stuff
write /proc/sys/kernel/printk_devkmsg off
write /proc/sys/kernel/sched_big_task_rotation 1
