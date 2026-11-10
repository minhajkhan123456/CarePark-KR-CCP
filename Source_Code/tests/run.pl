/* Run every plunit suite:   swipl tests/run.pl */
:- use_module('../engine/core').
:- use_module('../engine/allocate').
:- use_module('../engine/check').
:- use_module('../engine/backward').
:- use_module('../engine/fol').
:- use_module('../engine/dl').
:- use_module('../engine/frames').
:- use_module('../engine/semnet').
:- use_module('../kb/rules').
:- use_module('../kb/facts', []).
:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(yall)).
:- use_module(library(pairs)).
:- load_test_files([]).
:- consult([core, reasoning, day, kr]).
:- initialization((run_tests -> halt(0) ; halt(1)), main).
