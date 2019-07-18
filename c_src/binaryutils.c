/*
 * Copyright (C) 2002-2017 ProcessOne, SARL. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#include <erl_nif.h>
#include <string.h>
#include <iconv.h>

#define OK 0
#define ERR_MEMORY_FAIL 1

static int load(ErlNifEnv *env, void **priv, ERL_NIF_TERM load_info)
{
	return 0;
}

static int upgrade(ErlNifEnv *env, void **priv, void **old_priv, ERL_NIF_TERM load_info)
{
	return 0;
}

static void unload(ErlNifEnv *caller_env, void *priv_data)
{
}

static int do_convert(ErlNifEnv *env, char *from, char *to,
					  ErlNifBinary *string, ErlNifBinary *rstring)
{
	char *stmp = (char *)string->data;
	char *rtmp = (char *)rstring->data;
	size_t outleft = rstring->size;
	size_t inleft = string->size;
	int invalid_utf8_as_latin1 = 0;
	iconv_t cd;

	/* Special mode: parse as UTF-8 if possible; otherwise assume it's
      Latin-1.  Makes no difference when encoding. */
	if (strcmp(from, "utf-8+latin-1") == 0)
	{
		from[5] = '\0';
		invalid_utf8_as_latin1 = 1;
	}
	if (strcmp(to, "utf-8+latin-1") == 0)
	{
		to[5] = '\0';
	}
	cd = iconv_open(to, from);

	if (cd == (iconv_t)-1)
	{
		if (enif_realloc_binary(rstring, string->size))
		{
			memcpy(rstring->data, string->data, string->size);
			return OK;
		}
		else
		{
			return ERR_MEMORY_FAIL;
		}
	}

	while (inleft > 0)
	{
		if (iconv(cd, &stmp, &inleft, &rtmp, &outleft) == (size_t)-1)
		{
			if (invalid_utf8_as_latin1 && (*stmp & 0x80) && outleft >= 2)
			{
				/* Encode one byte of (assumed) Latin-1 into two bytes of UTF-8 */
				*rtmp++ = 0xc0 | ((*stmp & 0xc0) >> 6);
				*rtmp++ = 0x80 | (*stmp & 0x3f);
				outleft -= 2;
			}
			stmp++;
			if (inleft > 0)
				inleft--;
		}
	}

	iconv_close(cd);

	if (enif_realloc_binary(rstring, rtmp - (char *)rstring->data))
	{
		return OK;
	}
	else
	{
		return ERR_MEMORY_FAIL;
	}
}

static ERL_NIF_TERM convert(ErlNifEnv *env, int argc,
							const ERL_NIF_TERM argv[])
{

	ErlNifBinary from_bin, to_bin, string, rstring;
	char *from, *to;
	int rescode;

	if (argc == 3)
	{
		if (enif_inspect_iolist_as_binary(env, argv[0], &from_bin) &&
			enif_inspect_iolist_as_binary(env, argv[1], &to_bin) &&
			enif_inspect_iolist_as_binary(env, argv[2], &string))
		{
			from = enif_alloc(from_bin.size + 1);
			to = enif_alloc(to_bin.size + 1);
			if (from && to && enif_alloc_binary(4 * string.size, &rstring))
			{
				memcpy(from, from_bin.data, from_bin.size);
				memcpy(to, to_bin.data, to_bin.size);
				from[from_bin.size] = '\0';
				to[to_bin.size] = '\0';
				rescode = do_convert(env, from, to, &string, &rstring);
				enif_free(from);
				enif_free(to);
				if (rescode == OK)
				{
					return enif_make_binary(env, &rstring);
				}
				else
				{
					enif_release_binary(&rstring);
				}
			}
		}
	}

	return enif_make_badarg(env);
}

static ErlNifFunc nif_funcs[] =
	{
		{"convert", 3, convert}};

//ERL_NIF_INIT(MODULE, ErlNifFunc funcs[], load, reload, upgrade, unload
ERL_NIF_INIT(Elixir.Tds.BinaryUtils, nif_funcs, load, NULL, upgrade, unload)
