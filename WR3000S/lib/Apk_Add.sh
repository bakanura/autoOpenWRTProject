#!/bin/sh

Apk_Add() {
    Router_Ssh \
        apk add "$@"
}
