#!/bin/bash
: <<'HEADER'
===============================================================================
 LAPSLens | CI | AD | verify-readers.sh
===============================================================================
 Version:   3.0.0
 Author:    Joshua D. Miller, Claude
 Created:   2026-11-23
 Updated:   2026-11-23

 Purpose:
     Checks the domain the way LAPSLens uses it: a helpdesk tech in a
     "LAPS Readers" group, with the read and reset rights that
     Set-AdmPwdReadPasswordPermission / Set-LapsADReadPasswordPermission
     grant, binds over LDAPS and StartTLS with their UPN and reads both
     LAPS schemas by computer name; an ordinary user can't; a plain LDAP
     simple bind (no TLS) is refused. These are the fixtures the LAPSLens
     LDAP client is tested against (docs/TESTING.md).

 Usage:
     sudo -E bash .github/scripts/samba/verify-readers.sh
     Environment: ADMINPASS (required), REALM (default LAPS.TEST).
===============================================================================
 CHANGELOG
===============================================================================
 Version   Date         Author    Description
 -------   ----------   -------   --------------------------------------------
 3.0.0     2026-11-23   joshua    New file.
                        claude
===============================================================================
HEADER
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### --------- ###
### | Setup | ###
### --------- ###
set -uo pipefail
REALM=${REALM:-LAPS.TEST}
: "${ADMINPASS:?}"
LOWER=$(echo "$REALM" | tr 'A-Z' 'a-z')
BASEDN=$(echo "$LOWER" | sed 's/^/DC=/; s/\./,DC=/g')
SAM=/var/lib/samba/private/sam.ldb
SCHEMA="CN=Schema,CN=Configuration,$BASEDN"
FAIL=0
ok()  { echo "PASS: $*"; }
bad() { echo "::error::FAIL: $*"; FAIL=$((FAIL+1)); }
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq ldap-utils >/dev/null
# Samba's certificate is self-signed; LAPSLens will verify it properly.
export LDAPTLS_REQCERT=never

HELPDESK=helpdesk; HELPDESK_PASS='Help-Desk-7781!'
PLAIN=plainuser; PLAIN_PASS='Plain-User-5521!'

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ------------ ###
### | Fixtures | ###
### ------------ ###
### MACTEST01: legacy LAPS. WINTEST01: Windows LAPS (unencrypted JSON).     ###
now=$(date +%s); ft() { echo $(( ($1 + 11644473600) * 10000000 )); }
EXP=$(ft $((now + 30*86400))); UPD=$(printf '%x' "$(ft "$now")")
MAC_PW='Mac-Legacy-4410!'; WIN_PW='Win-LAPS-9921#'
for pc in MACTEST01 WINTEST01; do
  samba-tool computer create "$pc" >/dev/null && ok "computer $pc created" || bad "create $pc"
done
cat > /tmp/fixtures.ldif <<LDIF
dn: CN=MACTEST01,CN=Computers,$BASEDN
changetype: modify
replace: ms-Mcs-AdmPwd
ms-Mcs-AdmPwd: $MAC_PW
-
replace: ms-Mcs-AdmPwdExpirationTime
ms-Mcs-AdmPwdExpirationTime: $EXP

dn: CN=WINTEST01,CN=Computers,$BASEDN
changetype: modify
replace: msLAPS-Password
msLAPS-Password: {"n":"Administrator","t":"$UPD","p":"$WIN_PW"}
-
replace: msLAPS-PasswordExpirationTime
msLAPS-PasswordExpirationTime: $EXP
LDIF
ldbmodify -H ldap://localhost -U "Administrator%$ADMINPASS" /tmp/fixtures.ldif >/dev/null \
  && ok "fixture passwords written" || bad "fixture write"

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ------------------------------ ###
### | LAPS Readers and delegation | ###
### ------------------------------ ###
### Read + control access on the passwords (they're confidential), read    ###
### and write on the expirations ("rotate now").                            ###
samba-tool group add "LAPS Readers" >/dev/null
samba-tool user create "$HELPDESK" "$HELPDESK_PASS" >/dev/null
samba-tool user create "$PLAIN" "$PLAIN_PASS" >/dev/null
samba-tool group addmembers "LAPS Readers" "$HELPDESK" >/dev/null
SID=$(ldbsearch -H "$SAM" -b "$BASEDN" "(sAMAccountName=LAPS Readers)" objectSid | awk '/^objectSid:/{print $2}')
[ -n "$SID" ] && ok "LAPS Readers is $SID" || bad "no SID for LAPS Readers"
guid() { ldbsearch -H "$SAM" -b "$SCHEMA" "(lDAPDisplayName=$1)" schemaIDGUID | awk '/^schemaIDGUID:/{print $2}'; }
COMPUTER_CLASS=bf967a86-0de6-11d0-a285-00aa003049e2
SDDL=""
for attr in ms-Mcs-AdmPwd msLAPS-Password; do
  SDDL="$SDDL(OA;CI;RPCR;$(guid "$attr");$COMPUTER_CLASS;$SID)"
done
for attr in ms-Mcs-AdmPwdExpirationTime msLAPS-PasswordExpirationTime; do
  SDDL="$SDDL(OA;CI;RPWP;$(guid "$attr");$COMPUTER_CLASS;$SID)"
done
samba-tool dsacl set -H "$SAM" --objectdn="$BASEDN" --sddl="$SDDL" >/dev/null \
  && ok "delegated read/reset to LAPS Readers" || bad "dsacl set"

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### ----------- ###
### | Lookups | ###
### ----------- ###
### lookup <uri> <upn> <password> <computer> <attribute> [extra flags]     ###
lookup() {
  ldapsearch -LLL -o ldif-wrap=no -x -H "$1" ${6:-} -D "$2" -w "$3" -b "$BASEDN" \
    "(&(objectClass=computer)(sAMAccountName=$4\$))" "$5" 2>/dev/null | sed -n "s/^$5: //p"
}
UPN="$HELPDESK@$LOWER"
[ "$(lookup ldaps://localhost "$UPN" "$HELPDESK_PASS" MACTEST01 ms-Mcs-AdmPwd)" = "$MAC_PW" ] \
  && ok "helpdesk reads ms-Mcs-AdmPwd over LDAPS" || bad "helpdesk LDAPS ms-Mcs-AdmPwd"
[ "$(lookup ldap://localhost "$UPN" "$HELPDESK_PASS" MACTEST01 ms-Mcs-AdmPwd -ZZ)" = "$MAC_PW" ] \
  && ok "helpdesk reads ms-Mcs-AdmPwd over StartTLS" || bad "helpdesk StartTLS ms-Mcs-AdmPwd"
[ "$(lookup ldaps://localhost "$UPN" "$HELPDESK_PASS" MACTEST01 ms-Mcs-AdmPwdExpirationTime)" = "$EXP" ] \
  && ok "helpdesk reads ms-Mcs-AdmPwdExpirationTime" || bad "helpdesk expiration"
J=$(lookup ldaps://localhost "$UPN" "$HELPDESK_PASS" WINTEST01 msLAPS-Password)
python3 -c "import json,sys; d=json.loads(sys.argv[1]); assert d['n']=='Administrator' and d['p']==sys.argv[2] and int(d['t'],16)>0" "$J" "$WIN_PW" \
  && ok "helpdesk reads msLAPS-Password JSON {n,t,p}" || bad "msLAPS-Password: '$J'"

[ -z "$(lookup ldaps://localhost "$PLAIN@$LOWER" "$PLAIN_PASS" MACTEST01 ms-Mcs-AdmPwd)" ] \
  && ok "ordinary user cannot read ms-Mcs-AdmPwd" || bad "ms-Mcs-AdmPwd readable by ordinary user"
[ -z "$(lookup ldaps://localhost "$PLAIN@$LOWER" "$PLAIN_PASS" WINTEST01 msLAPS-Password)" ] \
  && ok "ordinary user cannot read msLAPS-Password" || bad "msLAPS-Password readable by ordinary user"

# Simple binds without TLS send the password in the clear: Samba refuses them,
# and LAPSLens never offers them.
if ldapsearch -LLL -x -H ldap://localhost -D "$UPN" -w "$HELPDESK_PASS" -b "$BASEDN" -s base dn >/dev/null 2>&1; then
  bad "plain LDAP simple bind (no TLS) was accepted"
else
  ok "plain LDAP simple bind (no TLS) is refused"
fi

# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: #
### -------------- ###
### | Rotate now | ###
### -------------- ###
### Setting the expiration to 0 makes the device rotate at its next check. ###
reset_ldif() {
  printf 'dn: CN=%s,CN=Computers,%s\nchangetype: modify\nreplace: %s\n%s: 0\n' "$1" "$BASEDN" "$2" "$2"
}
if reset_ldif MACTEST01 ms-Mcs-AdmPwdExpirationTime | ldapmodify -x -H ldaps://localhost -D "$UPN" -w "$HELPDESK_PASS" >/dev/null 2>&1 \
   && [ "$(lookup ldaps://localhost "$UPN" "$HELPDESK_PASS" MACTEST01 ms-Mcs-AdmPwdExpirationTime)" = "0" ]; then
  ok "helpdesk can force rotation (expiration 0)"
else
  bad "helpdesk could not reset ms-Mcs-AdmPwdExpirationTime"
fi
if reset_ldif WINTEST01 msLAPS-PasswordExpirationTime | ldapmodify -x -H ldaps://localhost -D "$PLAIN@$LOWER" -w "$PLAIN_PASS" >/dev/null 2>&1; then
  bad "ordinary user could reset msLAPS-PasswordExpirationTime"
else
  ok "ordinary user cannot force rotation"
fi

echo "----"; [ "$FAIL" -eq 0 ] && echo "All reader checks passed" || { echo "::error::$FAIL reader check(s) failed"; exit 1; }
