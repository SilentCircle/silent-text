@xmalloc@
identifier x;
position p;
@@
  x = <+... XMALLOC@p(...) ...+>;

@ok1@
identifier xmalloc.x;
position xmalloc.p;
statement S;
@@
  x = <+... XMALLOC@p(...) ...+>;
  ... when != x
  if (x == NULL)
    S

@ok2@
identifier xmalloc.x;
position xmalloc.p;
@@
  x = <+... XMALLOC@p(...) ...+>;
  ... when != x
  CKNULL(x);

@depends on !ok1 && !ok2@
identifier xmalloc.x;
position xmalloc.p;
type T;
statement S;
@@
  T err = ...;
  ...
  x = <+... XMALLOC@p(...) ...+>;
+ CKNULL(x);
  ...
  done:
    S
