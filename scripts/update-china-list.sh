output_file="modules/nixos/common-settings/china-domains.txt"
curl "https://raw.githubusercontent.com/peeweep/dnsmasq-china-list-raw/refs/heads/master/accelerated-domains.china.raw.txt" > "$output_file"
curl "https://raw.githubusercontent.com/peeweep/dnsmasq-china-list-raw/refs/heads/master/apple.china.raw.txt" >> "$output_file"
curl "https://raw.githubusercontent.com/peeweep/dnsmasq-china-list-raw/refs/heads/master/google.china.raw.txt" >> "$output_file"
# extra rules
cat >> $output_file <<- EOM
test.steampowered.com
steamserver.net
api.steampowered.com
EOM

