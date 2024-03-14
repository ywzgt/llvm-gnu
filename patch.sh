diff --git a/include/unistd.h b/include/unistd.h
index 36cd5fc..ca3f7dc 100644
--- a/include/unistd.h
+++ b/include/unistd.h
@@ -1259,4 +1259,17 @@ extern size_t __pagesize attribute_hidden;
 #endif
 
 
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
+int getentropy(void *, size_t);
+#endif
+
+#ifdef __cplusplus
+}
+#endif
+
+
 #endif /* unistd.h  */
diff --git a/libc/misc/Makefile.in b/libc/misc/Makefile.in
index caf7f13..b8e9045 100644
--- a/libc/misc/Makefile.in
+++ b/libc/misc/Makefile.in
@@ -16,6 +16,7 @@ include $(top_srcdir)libc/misc/file/Makefile.in
 include $(top_srcdir)libc/misc/fnmatch/Makefile.in
 include $(top_srcdir)libc/misc/ftw/Makefile.in
 include $(top_srcdir)libc/misc/fts/Makefile.in
+include $(top_srcdir)libc/misc/getentropy/Makefile.in
 include $(top_srcdir)libc/misc/getloadavg/Makefile.in
 include $(top_srcdir)libc/misc/glob/Makefile.in
 include $(top_srcdir)libc/misc/internals/Makefile.in
diff --git a/libc/misc/getentropy/Makefile b/libc/misc/getentropy/Makefile
new file mode 100644
index 0000000..4a8f4a0
--- /dev/null
+++ b/libc/misc/getentropy/Makefile
@@ -0,0 +1,13 @@
+# Makefile for uClibc
+#
+# Copyright (C) 2000-2005 Erik Andersen <andersen@uclibc.org>
+#
+# Licensed under the LGPL v2.1, see the file COPYING.LIB in this tarball.
+#
+
+top_srcdir=../../../
+top_builddir=../../../
+all: objs
+include $(top_builddir)Rules.mak
+include Makefile.in
+include $(top_srcdir)Makerules
diff --git a/libc/misc/getentropy/Makefile.in b/libc/misc/getentropy/Makefile.in
new file mode 100644
index 0000000..d7a3e87
--- /dev/null
+++ b/libc/misc/getentropy/Makefile.in
@@ -0,0 +1,23 @@
+# Makefile for uClibc
+#
+# Copyright (C) 2000-2008 Erik Andersen <andersen@uclibc.org>
+#
+# Licensed under the LGPL v2.1, see the file COPYING.LIB in this tarball.
+#
+
+subdirs += libc/misc/getentropy
+
+CSRC-y := getentropy.c
+
+MISC_GETENTROPY_DIR := $(top_srcdir)libc/misc/getentropy
+MISC_GETENTROPY_OUT := $(top_builddir)libc/misc/getentropy
+
+MISC_GETENTROPY_SRC := $(patsubst %.c,$(MISC_GETENTROPY_DIR)/%.c,$(CSRC-y))
+MISC_GETENTROPY_OBJ := $(patsubst %.c,$(MISC_GETENTROPY_OUT)/%.o,$(CSRC-y))
+
+libc-y += $(MISC_GETENTROPY_OBJ)
+
+objclean-y += CLEAN_libc/misc/getentropy
+
+CLEAN_libc/misc/getentropy:
+	$(do_rm) $(addprefix $(MISC_GETENTROPY_OUT)/*., o os)
diff --git a/libc/misc/getentropy/getentropy.c b/libc/misc/getentropy/getentropy.c
new file mode 100644
index 0000000..651ea95
--- /dev/null
+++ b/libc/misc/getentropy/getentropy.c
@@ -0,0 +1,33 @@
+#define _BSD_SOURCE
+#include <unistd.h>
+#include <sys/random.h>
+#include <pthread.h>
+#include <errno.h>
+
+int getentropy(void *buffer, size_t len)
+{
+	int cs, ret = 0;
+	char *pos = buffer;
+
+	if (len > 256) {
+		errno = EIO;
+		return -1;
+	}
+
+	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);
+
+	while (len) {
+		ret = getrandom(pos, len, 0);
+		if (ret < 0) {
+			if (errno == EINTR) continue;
+			else break;
+		}
+		pos += ret;
+		len -= ret;
+		ret = 0;
+	}
+
+	pthread_setcancelstate(cs, 0);
+
+	return ret;
+}
