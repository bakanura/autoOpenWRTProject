#!/bin/sh

Has_Default_Route() {
    Router_Ssh '
        ip route show default |
            grep -q "^default "
    '
}
