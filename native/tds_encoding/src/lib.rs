#[macro_use]
extern crate rustler;
#[macro_use]
extern crate rustler_codegen;
#[macro_use]
extern crate lazy_static;
#[macro_use]
extern crate encoding;


use encoding::{DecoderTrap, EncoderTrap};
use encoding::label::encoding_from_whatwg_label;

use rustler::{Env, Term, NifResult, Encoder};
use rustler::types::binary::{ Binary, OwnedBinary };
use rustler::{Error};

use std::io::Write;


mod atoms {
    rustler_atoms! {
        atom ok;
        atom error;
        atom unknown_encoding;
        //atom __true__ = "true";
        //atom __false__ = "false";
    }
}

rustler_export_nifs! {
    "Elixir.Tds.Encoding",
    [
        ("encode", 2, encode),
        ("decode", 2, decode)
    ],
    None
}

fn decode<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let enc : String = args[1].decode()?;

    match encoding_from_whatwg_label(&enc) {
        Some(encoding) => {
            let in_binary : Binary = args[0].decode()?;
            let in_str = in_binary.to_owned().unwrap();
            let res =  encoding.decode(in_str.as_slice(), DecoderTrap::Ignore).unwrap();
            return Ok(res.encode(env))
        },
        None => return Err(Error::BadArg),
    }
}

fn encode<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let enc : String = args[1].decode()?;
 
    match encoding_from_whatwg_label(&enc) {
        Some(encoding) => {
            let in_str : &str = args[0].decode()?;
            let enc_bin = encoding.encode(in_str, EncoderTrap::Ignore).unwrap();
            let mut bin = OwnedBinary::new(enc_bin.len()).unwrap();
            bin.as_mut_slice().write(&enc_bin).unwrap();
            return Ok(bin.release(env).encode(env))
        },
        None => return Err(Error::BadArg),
    }
}
