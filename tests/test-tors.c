#include <stdio.h>
 
void ctorTest(void) __attribute__ ((constructor));
void dtorTest(void) __attribute__ ((destructor));
  
void ctorTest(void) {
	printf ("ctor before main\n");
}
 
void dtorTest(void) {
    printf ("dtor after main\n");
}
 
int main() {
    printf("hello world\n");
    return 0;
}
