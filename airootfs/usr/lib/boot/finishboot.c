// C because it needs to be SUID
// Secoority: none

#include <stdlib.h>
#include <unistd.h>
int main()
{
	setuid(geteuid());
	system("/usr/bin/plymouth quit && /usr/bin/chvt 2");
	return 0;
}
