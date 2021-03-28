// karabiner complex rules
//
// If rule (switch command+q / command+shift+q) is applied, then remember to
// set command+q as other function in system preference, like inverse color
// (since it is now by default logout)

[
    {
        "description": "Change escape to backtick if pressed with command",
        "manipulators": [
            {
                "from": {
                    "key_code": "escape",
                    "modifiers": {
                        "mandatory": [
                            "left_command"
                        ]
                    }
                },
                "to": [
                    {
                        "key_code": "grave_accent_and_tilde",
                        "modifiers": [
                            "left_command"
                        ]
                    }
                ],
                "type": "basic"
            },
            {
                "from": {
                    "key_code": "escape",
                    "modifiers": {
                        "mandatory": [
                            "right_command"
                        ]
                    }
                },
                "to": [
                    {
                        "key_code": "grave_accent_and_tilde",
                        "modifiers": [
                            "right_command"
                        ]
                    }
                ],
                "type": "basic"
            }
        ]
    },
    {
        "description": "Switch Command+Shift+q and Command+q",
        "manipulators": [
            {
                "from": {
                    "key_code": "q",
                    "modifiers": {
                        "mandatory": [
                            "command",
                            "shift"
                        ]
                    }
                },
                "to": [
                    {
                        "key_code": "q",
                        "modifiers": [
                            "command"
                        ]
                    }
                ],
                "type": "basic"
            },
            {
                "from": {
                    "key_code": "q",
                    "modifiers": {
                        "mandatory": [
                            "command"
                        ]
                    }
                },
                "to": [
                    {
                        "key_code": "q",
                        "modifiers": [
                            "command",
                            "shift"
                        ]
                    }
                ],
                "type": "basic"
            }
        ]
    },
    {
        "description": "Switch left-alt and left-command if in VirtualBox VM",
        "manipulators": [
            {
                "conditions": [
                    {
                        "bundle_identifiers": [
                            "^org.virtualbox.app.VirtualBoxVM$"
                        ],
                        "type": "frontmost_application_if"
                    }
                ],
                "from": {
                    "key_code": "left_command",
                    "modifiers": {
                        "optional": [
                            "any"
                        ]
                    }
                },
                "to": [
                    {
                        "key_code": "left_option"
                    }
                ],
                "type": "basic"
            },
            {
                "conditions": [
                    {
                        "bundle_identifiers": [
                            "^org.virtualbox.app.VirtualBoxVM$"
                        ],
                        "type": "frontmost_application_if"
                    }
                ],
                "from": {
                    "key_code": "left_option",
                    "modifiers": {
                        "optional": [
                            "any"
                        ]
                    }
                },
                "to": [
                    {
                        "key_code": "left_command"
                    }
                ],
                "type": "basic"
            }
        ]
    }
]
