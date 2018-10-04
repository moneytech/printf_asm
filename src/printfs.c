//this file will probably only work on gcc
#include <stdint.h>
#include <stdarg.h> //these are needed to support var args
#include "common.h"


int strlenc(const char *s)
{
    int len = 0;
    while (*(s++)){
        len++;
    }
    return len;
}
int memcpyc(char *a, char *b, int len)
{
    while (len--){
        *(a++) = *(b++);
    }
    return len;
}

__attribute__((force_align_arg_pointer))
int printfs(const char *format, ...)
{
    va_list ap;
    const char *tmp;
    int argc = 0;
    int idx = 0;
    uint64_t args[MAXARGS];
    char buff[BUFFSIZE];
    va_start(ap, format);

    tmp = format;
    double d;
    uint64_t g;
    const char *s;
    //because it's x86-64, there is no straight forward way to do it without knowing the operand sizes :P 
    // (in x86 var args were easy to deal with)
    //this is kind of cheating
    while (*tmp){ 
        if (*tmp == '%' && *(tmp+1) != '%'){
            lbl:
            switch(tmp[1]){
                case 'f':
                case 'g':
                    d = va_arg(ap, double);
                    args[idx++] = *((uint64_t *) &d);
                    break;
                case 'd':
                case 'x':
                case 'X':
                case 'o':
                case 'b':
                case 's':
                case 'c':
                    g = va_arg(ap, uint64_t);
                    args[idx++] = *((uint64_t *) &g);
                    break;
                default:
                    tmp++;
                    goto lbl;
            }
        }
        tmp++;
    }
    va_end(ap);

    sprintfn(buff, BUFFSIZE, format, (void *)args);
    write(1, buff, strlenc(buff));
    return 0;
}
