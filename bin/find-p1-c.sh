find . -name '*.c' -print | gawk -F/ '{print $NF}' | uniq | wc
find p1/exe -name '*.c' -print | gawk -F/ '{print $NF}' | uniq | wc
find . -name '1-*.c' -print
