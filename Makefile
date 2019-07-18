MIX = mix
# ICONV_VER = 1.9.1
ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS = -g -O2 -Wall -I$(ERLANG_PATH)

# ifeq ($(wildcard ../libiconv),)
# 	ICONV_PATH = ../libiconv
# else
#   $(shell mkdir -p tmp)
#   $(shell curl -L http://ftp.gnu.org/pub/gnu/libiconv/libiconv-$(ICONV_VER).tar.gz | tar xz -C tmp)
# 	ICONV_PATH = c_src/libiconv-$(ICONV_VER)
# endif

# CFLAGS += -I$(ICONV_PATH)/src

ifneq ($(OS),Windows_NT)
	CFLAGS += -fPIC

	ifeq ($(shell uname),Darwin)
		LDFLAGS += -dynamiclib -undefined dynamic_lookup
	endif
endif

.PHONY: all tds clean

all: tds

tds:
	$(MIX) compile

priv/binaryutils.so: c_src/binaryutils.c
	$(CC) $(CFLAGS) -shared $(LDFLAGS) -o $@ c_src/binaryutils.c

priv/binaryutils.dll: c_src/binaryutils.c
	$(CC) $(CFLAGS) -shared $(LDFLAGS) -o $@ c_src/binaryutils.c

clean:
	$(MIX) clean
	$(RM) -fr priv
