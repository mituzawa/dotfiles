who | awk '{print $1}' | uniq | sort > `date +%m%d`-attendee
csplit `date +%m%d`-attendee 20
