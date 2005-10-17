#!/usr/bin/perl -w
#

use Torture::Utils;
my $dn="cn=pippo,bc=pluto,cz=topolino";
my $dnstronzo="cn=pi\\,p\\,po\\ ,bc=pluto,cz=topolino";
my $value="cn=f;lk(jds sld,k!fj ";

print 'dn: ' . $dn . ' -- parent: ' . Torture::Utils::dnParent($dn) . "\n";
print 'dnstronzo: ' . $dnstronzo . ' -- parent: ' . Torture::Utils::dnParent($dnstronzo) . "\n";
print 'escaping: ' . $value . ' -- escaped: ' . Torture::Utils::attribEscape($value) . "\n";
print 'relative: ' . $dn . ' - ' . Torture::Utils::dnRelative($dn) . ' -- relative (stronzo): ' . 
	$value . ' - ' . Torture::Utils::dnRelative(Torture::Utils::attribEscape($value)) . "\n";
print 'child: ' . $dn . ' - ' . Torture::Utils::dnChild($dn) . "\n";
print 'childstronzo: ' . $dnstronzo . ' - ' . Torture::Utils::dnChild($dnstronzo) . "\n";

