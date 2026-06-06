if [ $# -ne 1 ]; then
    echo "Usage: $0 [run|run-only|clean]" 1>&2
    exit 1
fi

cd $PATH_OPTEE/build; export PATH=/home/mituzawa/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; make -j16 CFG_CORE_ASLR=y GDBSERVER=y CFG_PAGED_USER_TA=y CFG_TEE_CORE_LOG_LEVEL=3 CFG_TEE_TA_LOG_LEVEL=3 $1
