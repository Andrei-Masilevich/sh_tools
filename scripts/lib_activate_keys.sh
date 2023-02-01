#!/bin/bash

function obtain_ssh_environment()
{
    if [ -f $HOME/.ssh/ssh-agent.env ]; then
        . $HOME/.ssh/ssh-agent.env 2>/dev/null
    fi
}

