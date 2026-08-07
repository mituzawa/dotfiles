who | awk '{print $1}' | sort | uniq >$(date +%m%d)-attendee
csplit $(date +%m%d)-attendee 20
