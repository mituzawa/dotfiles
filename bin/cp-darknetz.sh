if [ ! -d $PATH_OPTEE/optee_examples/darknetz ]; then
    echo "Creating $PATH_OPTEE/optee-examples/darknetz"
    mkdir $PATH_OPTEE/optee_examples/darknetz
    cp -a $PATH_darknetz/. $PATH_OPTEE/optee_examples/darknetz/
else
    echo "Do not do this, because it will overwrite fixed files!"
fi
