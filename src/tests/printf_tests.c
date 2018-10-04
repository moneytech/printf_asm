#include <stdint.h>
#include "../common.h"

void dont_segfault2(){
    #define BBLEN 20
    char buffer[BBLEN];


    uint64_t args[9];
    const char *str = "abcdefghijklmnopqrstuvwxyz";
    const char *format = "DONT SEGFAULT! %s\n";
    double verybig = 1.0;
    for(int i=0; i<20; i++){
        verybig *= 10.0;
    }
    args[0] = ((uint64_t *) str);
    
    sprintfn(buffer, BBLEN, format, (void *) args);
    write(1, buffer, strlenc(buffer));
}

void dont_segfault(){
    #undef BBLEN
    #define BBLEN 1000
    char buffer[BBLEN];


    uint64_t args[9];
    const char *format = "DONT SEGFAULT! %.4f\n";
    double verybig = 1.0;
    for(int i=0; i<20; i++){
        verybig *= 10.0;
    }
    args[0] = *((uint64_t *) &verybig);
    
    sprintfn(buffer, BBLEN, format, (void *)args);
    write(1, buffer, strlenc(buffer));
}



int main(void)
{

    int s = printfs("num: %d, str:%sv\n", 32, "hello");
    s = printfs("rt: %dx\n", s);
    s = printfs("expected: 123, got: %3d\n", 123456);
    s = printfs("expected: ff, got: %x\n", 255);
    s = printfs("expected: FF, got: %X\n", 255);
    s = printfs("expected: FF short, got: %hx\n", (short)255);
    s = printfs("expected: FF char, got: %hhx\n", (char)-1);
    s = printfs("expected: FE char, got: %hhx\n", 1024+255-1);
    s = printfs("expected: 400 , got: %X\n", 255);
    s = printfs("expected: 0x400 , got: %#X\n", 255);
    s = printfs("expected: 0x400 , got: %#x\n", 255);
    s = printfs("expected: 02000 , got: %#o\n", 255);
    s = printfs("expected: 10 (octal) , got: %o\n", 8);
    s = printfs("expected: 11 (octal) , got: %o\n", 9);
    s = printfs("expected: a bunch of fffs , got: %x\n", -1);
    s = printfs("expected: w (char) got: %c\n", 'w');
    s = printfs("expected: 100%% got: 100%%\n");
    s = printfs("expected: a larger bunch of fffs , got: %lx\n", -1L);
    s = printfs("expected: -1, got: %d\n", -1);
    s = printfs("expected: some positive number, got: %ld\n", -1L);
    s = printfs("expected: 10000000003, got: %ld\n", 10000000003L);
    s = printfs("expected: 10000000003, got: %lld\n",10000000003L);
    s = printfs("expected: +1, got: %+d\n", 1);
    s = printfs("expected: +1, got: %+ld\n", 1L);
    s = printfs("expected: 1011, got: %b\n", 11);
    s = printfs("expected: ld, got: %llld\n", 11);
    s = printfs("expected: 0xff, got: %#x\n", 255);
    s = printfs("expected: 0xFF, got: %#X\n", 255);
    s = printfs("expected: 0377, got: %#o\n", 255);
    s = printfs("expected: 3.1483, got: %.4f\n", 3.1483);
    s = printfs("expected: 3.148, got: %.3f\n", 3.1483);
    s = printfs("expected: 3.14, got: %.2f\n", 3.1483);
    s = printfs("expected: 3, got: %.0f\n", 3.1483);
    s = printfs("expected: 3.0, got: %f \n", 3.0);
    s = printfs("expected: 31.0, got: %f \n", 31.0);
    s = printfs("expected: 30.0, got: %f \n", 30.0);
    s = printfs("expected: 300.0, got: %f \n", 300.0);
    s = printfs("expected: 30.1, got: %f \n", 30.1);
    s = printfs("expected: 32000.0, got: %f \n", 32000.0);
    s = printfs("expected: 24325.0.0, got: %f \n", 24325.0);
    s = printfs("expected: -83725.0, got: %f \n", -83725.0);
    s = printfs("expected: 13.0, got: %f \n", 13.0);
    s = printfs("expected: 9.0, got: %f \n", 9.0);
    s = printfs("expected: 11.0, got: %f \n", 11.0);
    s = printfs("expected: 11.0,12.3, got: %f,%f \n", 11.0, 12.3);
    s = printfs("expected: 3.14  12.3, got: %.4f,  %f \n", 3.14, 12.3);
    s = printfs("expected: 0b11111111, got: %#b\n", 255);
    s = printfs("rt: %dx\n", s);

    double pi = 3.141592653589793;
    s = printfs("expected: Hello world 3.14 0xFF 9877, got: %s %.2f %hhX %d\n", "Hello world", pi, 255, 9877);
    s = printfs("%d %s %d\n", 255,"cryptonix2!" ,257); 
    s = printfs("DONT PRINT 0.299999999 : %f\n", 3.0/10.0); 
    s = printfs("DONT PRINT REPEATING DIGITS : %f\n", 15.0/18.0);
    s = printfs("DONT PRINT REPEATING DIGITS : %f\n", 1.0/3.0);  
    s = printfs("DONT PRINT REPEATING DIGITS : %f\n", 1.0/7.0);  
    s = printfs("DONT PRINT REPEATING DIGITS : %.10f\n", 1.0/8.0);  
    s = printfs("DONT PRINT REPEATING DIGITS : %.0f\n", 1.0/8.0);  
    s = printfs("DONT PRINT REPEATING DIGITS : %.1f\n", 1.0/8.0); 

    dont_segfault();
    dont_segfault2();

}


void _start()
{
    //align stack pointer
    //cool trick 
    asm("andq $-16,%rsp");
    asm("mov   %rsp, %rbp");

    main();
    //exit
    asm("mov   $60, %rax");
    asm("syscall");
}
