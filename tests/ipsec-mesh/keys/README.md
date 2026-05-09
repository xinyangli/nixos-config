# Test-only IPsec keypair

Generated with:

    openssl genpkey -algorithm ed25519 -out org.key
    openssl pkey -in org.key -pubout -out org.pub

These keys are committed deliberately for the `ipsec-mesh-test` NixOS VM
test only. They authenticate three throwaway VMs against each other inside
a hermetic test driver and have no relationship to any production
identity. Do not reuse outside of `tests/ipsec-mesh/`.
