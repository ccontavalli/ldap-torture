#include <stdlib.h>
#include <string.h>

# define dscm_malloc(size) malloc(size)

  /* Set handling routines */
typedef char dscm_set_t[32];
# define dscm_set_isin(set, ch) (((set)[(unsigned int)((ch)/8)])&(1<<((ch)%8)))


  /* + , ; < > \ */
static const char dscm_static_set_ldap_escape_dn[] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x58,
  0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

  /* ( ) * \ */
static const char dscm_static_set_ldap_escape_filter[] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

void dscm_ldap_escape_dn(char * string, char ** retval) {
  char * str;
  char * toret;
  int escape=0;
  int size=0;

    /* Those characters need only be escaped
     * at the beginning of the line */
  if(*string == '#' || *string == ' ')
    escape++;

    /* Calculate resulting string size */
  for(str=string; *str; size++, str++)
    if(dscm_set_isin(dscm_static_set_ldap_escape_dn, *str))
      escape++;

    /* allocate memory for result */
  *retval=toret=(char *)dscm_malloc(size+escape+1);

    /* If we don't need to escape anything */
  if(!escape) {
    memcpy(toret, string, size+1);

    return;
  }

    /* Escape the first character */
  if(*string == '#' || *string == ' ') {
    *toret++='\\';
    *toret++=*string++;
  }

    /* Escape all remaining characters */
  for(; *string; toret++, string++) {
    if(dscm_set_isin(dscm_static_set_ldap_escape_dn, *string))
      *toret++='\\';
    *toret=*string;
  }
  *toret='\0';

  return;
}

void dscm_ldap_escape_filter(char * string, char ** retval) {
  static const char hex[] = "0123456789ABCDEF";
  char * str;
  char * toret;
  int escape=0;
  int size=0;

    /* Calculate resulting string size */
  for(str=string; *str; size++, str++)
    if(dscm_set_isin(dscm_static_set_ldap_escape_filter, *str))
      escape++;

    /* allocate memory for result */
  toret=*retval=dscm_malloc(size+(escape<<1)+1);

    /* If we don't need to escape anything */
  if(!escape) {
    memcpy(toret, string, size+1);
    return;
  }

    /* Escape all remaining characters */
  for(; *string; toret++, string++) {
    if(dscm_set_isin(dscm_static_set_ldap_escape_filter, *string)) {
      *toret++='\\';
      *toret++=hex[(unsigned int)((*string)>>4)];
      *toret=hex[(unsigned int)((*string)&0xf)];
    } else
      *toret=*string;
  }
  *toret='\0';

  return;
}

