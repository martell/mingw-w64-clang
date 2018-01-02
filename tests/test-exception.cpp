#include <exception>
#include <stdio.h>

int main(int argc, char* argv[]) {
	try {
		throw std::exception();
	} catch (std::exception& e) {
		printf("caught std::exception\n");
	}
	return 0;
}
