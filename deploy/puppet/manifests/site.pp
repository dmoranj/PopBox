    node /^agent/ {
	include agentpopbox
    }

    node /^redis/ {
	include redispopbox
    }

    node /^lb/ {
        include lbpopbox
    }
