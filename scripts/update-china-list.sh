output_file="modules/nixos/common-settings/china-domains.txt"
curl "https://raw.githubusercontent.com/peeweep/dnsmasq-china-list-raw/refs/heads/master/accelerated-domains.china.raw.txt" > "$output_file"
curl "https://raw.githubusercontent.com/peeweep/dnsmasq-china-list-raw/refs/heads/master/apple.china.raw.txt" >> "$output_file"
curl "https://raw.githubusercontent.com/peeweep/dnsmasq-china-list-raw/refs/heads/master/google.china.raw.txt" >> "$output_file"
