#include <stdio.h>
#include <stdlib.h>

#define BUFF_LEN 512
char buff[BUFF_LEN];
extern int sprintfn(char *dest, ssize_t len, const char *format, const char **args);
extern int itoss(char *dest, ssize_t len, long num, long base);
extern int atois(char *_, char *__, const char *str);
//;	prototype(char *dest, long long size, long long num, long long base)
//
void test_atoi_itos()
{
	int num;
	num = atois(0, 0, "15");
	printf("passed atois 15 got %d\n", num);
	num = atois(0, 0, "-15");
	printf("passed atois -15 got %d\n", num);
	num = atois(0, 0, "12425");
	printf("passed atois 12425 got %d\n", num);
	num = atois(0, 0, "-12425");
	printf("passed atois -12425 got %d\n", num);

	int s;
	char buffer[8];
	char buffer_s[4];

	s = itoss(buffer, 8, 15, 10);
	printf("passed '15' base 10 to itos got the string: %s, rt: %d\n", buffer, s);
	s = itoss(buffer, 8, 128, 10);
	printf("passed '128' base 10 to itos got the string: %s, rt: %d\n", buffer, s);
	s = itoss(buffer, 8, 33, 16);
	printf("passed '33' base 16 to itos got the string: %s, rt: %d\n", buffer, s);
	s = itoss(buffer, 8, 255, 16);
	printf("passed '255' base 16 to itos got the string: %s, rt: %d\n", buffer, s);
	s = itoss(buffer, 8, 255, 2);
	printf("passed '255' base 2 buffsz:8 to itos got the string: %s, rt: %d\n", buffer, s);
	s = itoss(buff, 250, 255, 2);
	printf("passed '255' base 2 buffsz:256 to itos got the string: %s, rt: %d\n", buff, s);
	s = itoss(buffer, 8, 9, 2);
	printf("passed '9' base 2 to itos got the string: %s, rt: %d\n", buffer, s);
	s = itoss(buffer, 8, -24400, 10);
	printf("passed '-24400' base 10 to itos got the string: %s, rt: %d\n", buffer, s);
	s = itoss(buffer_s, 4, 133, 10);
	printf("passed '133' base 10 to itos with a buffer size of 4 got the string: %s, rt: %d\n", buffer_s, s);
	s = itoss(buffer_s, 4, -133, 10);
	printf("passed '-133' base 10 to itos with a buffer size of 4 got the string: %s, rt: %d\n", buffer_s, s);
	s = itoss(buffer_s, 4, 14333, 10);
	printf("passed '14333' base 10 to itos with a buffer size of 4 got the string: %s, rt: %d\n", buffer_s, s);


}
int main(int argc, const char **arg)
{

	if (0 ){
	sprintfn(buff, BUFF_LEN, "hello world!", NULL);
	printf("buff: \"%s\" \n", buff);

	sprintfn(buff, BUFF_LEN, "hello %%100 world!", NULL);
	printf("buff: \"%s\" \n", buff);
	
	sprintfn(buff, BUFF_LEN, "hello %100 world!", NULL); //shouldn't complete (it exits because not implemented now)
	printf("buff: \"%s\" \n", buff);
	}

	const char *argv1[] = {"stupid string!", NULL};
	sprintfn(buff, BUFF_LEN, "string: %s", argv1); 
	printf("buff: \"%s\" \n", buff);

	test_atoi_itos();

	const char *argv2[] = {"stupid string!", "number", NULL};
	sprintfn(buff, BUFF_LEN, "string: '%s' num: %d", argv2); 
	sprintfn(buff, BUFF_LEN, "string with limit of 4: '%4s' num: %d", argv2); 
	printf("buff: \"%s\" \n", buff);


	const char *argv3[] = {NULL, "stupid string!", "number", NULL};
	((long long *) argv3)[0] = 5233;
	((long long *) argv3)[1] = 1234567;


	sprintfn(buff, 50, "number printf test: %d another number: %d", argv3);
	printf("buff: '%s'\n", buff);
	sprintfn(buff, 50, "number printf test: %2d another number: %3d", argv3);
	printf("buff: '%s'\n", buff);


    int c = 0;
    float a = -432.732;
    double b = -432.732;
	printf("[] libc testing errors: %lld \n", 12); 
	printf("[] libc testing errors: %llld %ld \n", 12); 
	printf("actual -> provided in format, all should be -432.732\n"); 
	printf("[] libc testing floats f%%f: %f\n",a); 
	printf("[] libc testing floats f%%lf: %lf\n",a); 
	printf("[] libc testing floats lf%%lf: %lf \n",b); 
	printf("[] libc testing floats lf%%f: %f \n",b); 
	printf("[] libc testing floats 50 zeroz lf%%f: %f \n",5*100000000000000000000000000000000000000000000000000.0); 
    printf("size double:%d size float :%d\n", sizeof(double), sizeof(float));
    printf("size Ldouble:%d", sizeof(long double));



}
