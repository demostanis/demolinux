// C because it needs to be SUID
// Secoority: none

#include <stdlib.h>
#include <unistd.h>
int main()
{
	setuid(geteuid());
	system("plymouth quit && chvt 2");
	return 0;
}
