#ifndef ASMPRINTF_H
#define ASMPRINTF_H

typedef long long ssize_t;

#define MAXARGS 64
#define BUFFSIZE 512

extern int sprintfn(char *dest, ssize_t len, const char *format, const char **args);
extern int itoss(char *dest, ssize_t len, long num, long base);
extern int atois(char *_, char *__, const char *str);
extern int write(int, char *, long);

int strlenc(const char *s);
int memcpyc(char *a, char *b, int len);
int printfs(const char *format, ...);

#endif
