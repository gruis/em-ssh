module EM
  class Ssh < EventMachine::Connection
    # Copyright (c) 2008 Jamis Buck
    
    #--
    # Transport layer generic messages
    #++

    DISCONNECT                = 1
    IGNORE                    = 2
    UNIMPLEMENTED             = 3
    DEBUG                     = 4
    SERVICE_REQUEST           = 5
    SERVICE_ACCEPT            = 6

    #--
    # Algorithm negotiation messages
    #++

    KEXINIT                   = 20
    NEWKEYS                   = 21
    
    #--
    # Key exchange method specific messages
    #++
    
    KEXDH_INIT                = 30
    KEXDH_REPLY               = 31
    
    
    #--
    # Authentication specific messages
    #++
    USERAUTH_REQUEST          = 50
    USERAUTH_FAILURE          = 51
    USERAUTH_SUCCESS          = 52
    USERAUTH_BANNER           = 53

    USERAUTH_PASSWD_CHANGEREQ = 60
    USERAUTH_PK_OK            = 60

    USERAUTH_METHOD_RANGE     = 60..79
    
    
    #--
    # Connection protocol generic messages
    #++

    GLOBAL_REQUEST            = 80
    REQUEST_SUCCESS           = 81
    REQUEST_FAILURE           = 82

    #--
    # Channel related messages
    #++

    CHANNEL_OPEN              = 90
    CHANNEL_OPEN_CONFIRMATION = 91
    CHANNEL_OPEN_FAILURE      = 92
    CHANNEL_WINDOW_ADJUST     = 93
    CHANNEL_DATA              = 94
    CHANNEL_EXTENDED_DATA     = 95
    CHANNEL_EOF               = 96
    CHANNEL_CLOSE             = 97
    CHANNEL_REQUEST           = 98
    CHANNEL_SUCCESS           = 99
    CHANNEL_FAILURE           = 100

    
  end # module::Ssh
end # module::EM