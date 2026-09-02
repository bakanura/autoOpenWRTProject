#!/bin/sh

Test_Router_Internet() {
    Router_Ssh '
        ping \
            -c 2 \
            -W 3 \
            1.1.1.1 \
            >/dev/null 2>&1
    '
}
