#include <stdio.h>
#include <ldap.h>

#ifndef LDAP_SERVER
# error "Missing server name -- use -DLDAP_SERVER='server'"
#endif
#ifndef LDAP_SIMPLE
# error "authentications other than simple are not supported -- use -DLDAP_SIMPLE to use simple authentication"
#endif

#ifndef LDAP_USERNAME
# error "define LDAP_USERNAME with the username to use -- use -DLDAP_USERNAME=''"
#endif

#ifndef LDAP_PASSWORD
# error "define LDAP_PASSWORD with the password to use -- use -DLDAP_PASSWORD=''"
#endif

int main(void) {
  int status;
  char * mechanism=NULL;

  int ldap_version=LDAP_VERSION_3;
  int ldap_derefernce=LDAP_DEREF_ALWAYS;

  LDAP * ldap;

  status=ldap_initialize(&ldap, LDAP_SERVER);
  if(status != LDAP_SUCCESS || !ldap) {
    perror("ldap_initialize failed");
    return 1;
  }

    /* Use LDAP protocol VERSION 3 */
  if(ldap_set_option(ctx->ldap, LDAP_OPT_PROTOCOL_VERSION, &ldap_version) == -1 ||
     ldap_set_option(ctx->ldap, LDAP_OPT_DEREF, &ldap_dereference) == -1) {
    perror("set option failed");
    return 2;
  }

    /* Try to bind */
  status=ldap_simple_bind_s(ldap, LDAP_USERNAME, LDAP_PASSWORD);
  if(status != LDAP_SUCCESS) {
    perror("simple bind failed");
    return 3;
  }


  return 0;
}
