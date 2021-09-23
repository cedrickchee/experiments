#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

main() {
  int rc;
  struct sockaddr_in ssa, csa;
  int ss, cs;

  memset(&ssa, 0, sizeof ssa);
  ssa.sin_family = PF_INET;
  ssa.sin_port = htons(8080);
  ssa.sin_addr.s_addr = htonl(INADDR_ANY);

  ss = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
  bind(ss, (struct sockaddr*)&ssa, sizeof ssa);
  listen(ss, 5);

  for (;;) {
    int ln;
    static char rq[1000];
    memset(&csa, 0, sizeof csa);
    ln = sizeof(struct sockaddr);
    cs = accept(ss, (struct sockaddr*)&csa, &ln);
    memset(rq, 0, sizeof rq);
    recv(cs, rq, sizeof rq, 0);

    if (!strncmp(rq, "GET /", 5)) {
      char *b;
      FILE *f;
      char *fn;
      if (b = strchr(rq + 5, ' ')) *b = 0;
      else rq[sizeof rq - 1] = 0;
      if (fn = malloc(strlen(rq + 5) + 5)) {
        char *t, *type();
        strcpy(fn, "www/");
        strcat(fn, rq + 5);
        if ((t = type(fn)) && (f = fopen(fn, "rt"))) {
          int n;
          static char h[] = "HTTP/1.1 200 OK\nContent-Type: ";
          static char c[1000];
          strcpy(c, h);
          strcat(c, t);
          strcat(c, "\n\n");
          sendall(cs, c, strlen(c));
          while ((n = fread(c, 1, sizeof c, f)) > 0) sendall(cs, c, n);
          fclose(f);
        }
        else {
          static char h[] = "HTTP/1.1 404 NotFound\nContent-Type: text/html\n\n404 Nice try!";
          sendall(cs, h, sizeof h - 1);
        }
        free(fn);
      }
    }
    close(cs);
  }

  close(ss);
  return 0;
}

sendall(s, c, n)
char *c;
{
  int m; for (m = 0; (m += send(s, c + m, n - m, 0)) < n;);
}

char *type(fn)
char *fn;
{
  static char *s[] = {
    ".html", "text/html",
    ".asm", "text/plain",
    ".c", "text/plain",
    ".py", "text/plain" };
  int i;
  for (i = 0; i < sizeof s / sizeof *s; i += 2)
    if (strstr(fn, s[i]))
      return s[i + 1];
  return 0;
}
