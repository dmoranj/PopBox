    node /^agent/ {
      
      # Note the quotes around the name! Node names can have characters that
      # aren't legal for class names, so you can't always use bare, unquoted
      # strings like we do with classes.
      
      # Any resource or class declaration can go inside here. For now:
      
      
      file {'/home/ubuntu/prueba2': 
        content => "Cuack",
      }

    }
