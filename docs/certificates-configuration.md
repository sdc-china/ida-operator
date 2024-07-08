## Configuring IDA Certificates

### Configuring a signed-certificate for IDA

Step 1. Obtain the private key and public certificate of signed-certificate

Step 2. Combine the private key and public certificate into a PEM file

```
#For example:
cat ida.key > /root/ida.pem
cat ida.crt >> /root/ida.pem
```

Step 3. Configure IDA certificate parameter

```
scripts/deployIDA.sh --tls-cert <tls_cert>
#For example:
scripts/deployIDA.sh --tls-cert /root/ida.pem
```

### Configuring trusted LDAPS certificate in IDA

Step 1. Export LDAPS server certificate into a file

```
openssl s_client -showcerts -connect <LDAPS server host>:<LDAP server port> </dev/null 2>/dev/null|openssl x509 -outform PEM > /root/ldapserver-cert.crt

#For example:
openssl s_client -showcerts -connect c97721v.fyre.com:636 </dev/null 2>/dev/null|openssl x509 -outform PEM > /root/ldapserver-cert.crt
```

Step 2. Configure LDAPS certificate parameter

```
scripts/deployIDA.sh --tls-cert <ldap_tls_cert>
--ldap-tls-cert

#For example:
scripts/deployIDA.sh --ldap-tls-cert /root/ldapserver-cert.crt
```

