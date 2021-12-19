#!/system/bin/sh

# Memory tuning
function configure_memory_parameters() {
    # Set Memory parameters.
    #
    # Set Low memory killer minfree parameters.
    #

    arch_type=$(uname -m)
    MemTotalStr=$(cat /proc/meminfo | grep MemTotal)
    MemTotal=${MemTotalStr:16:8}

    # Read adj series and set adj threshold for PPR and ALMK.
    # This is required since adj values change from framework to framework.
    adj_series=`cat /sys/module/lowmemorykiller/parameters/adj`
    adj_1="${adj_series#*,}"
    set_almk_ppr_adj="${adj_1%%,*}"

    # PPR and ALMK should not act on HOME adj and below.
    # Normalized ADJ for HOME is 6. Hence multiply by 6
    # ADJ score represented as INT in LMK params, actual score can be in decimal
    # Hence add 6 considering a worst case of 0.9 conversion to INT (0.9*6).
    # For uLMK + Memcg, this will be set as 6 since adj is zero.
    set_almk_ppr_adj=$(((set_almk_ppr_adj * 6) + 6))
    echo $set_almk_ppr_adj > /sys/module/lowmemorykiller/parameters/adj_max_shift

    # Calculate vmpressure_file_min as below & set for 64 bit:
    # vmpressure_file_min = last_lmk_bin + (last_lmk_bin - last_but_one_lmk_bin)
    if [ "$arch_type" == "aarch64" ]; then
        minfree_series=$(cat /sys/module/lowmemorykiller/parameters/minfree)
        minfree_1="${minfree_series#*,}" ; rem_minfree_1="${minfree_1%%,*}"
        minfree_2="${minfree_1#*,}" ; rem_minfree_2="${minfree_2%%,*}"
        minfree_3="${minfree_2#*,}" ; rem_minfree_3="${minfree_3%%,*}"
        minfree_4="${minfree_3#*,}" ; rem_minfree_4="${minfree_4%%,*}"
        minfree_5="${minfree_4#*,}"

        vmpres_file_min=$((minfree_5 + (minfree_5 - rem_minfree_4)))
        echo $vmpres_file_min > /sys/module/lowmemorykiller/parameters/vmpressure_file_min
    fi

    # Setup memfree
    # echo "9543,19086,28629,38172,47715,57258" > /sys/module/lowmemorykiller/parameters/minfree

    # Enable oom_reaper
    if [ -f /sys/module/lowmemorykiller/parameters/oom_reaper ]; then
        echo 1 > /sys/module/lowmemorykiller/parameters/oom_reaper
    fi

    # Set allocstall_threshold to 0 for all targets.
    echo 0 > /sys/module/vmpressure/parameters/allocstall_threshold

    # Disable wsf for all targets beacause we are using efk.
    # wsf Range : 1..1000 So set to bare minimum value 1.
    echo 1 > /proc/sys/vm/watermark_scale_factor
}

configure_memory_parameters

if [ $? -eq 0 ]; then
  echo "[Genom] almk config done" > /proc/bootprof
else
  echo "[Genom] almk config failed" > /proc/bootprof
fi
