select(.body!="[deleted]")|
    (.body |= (
        gsub("\\s$"; "")|
        gsub("&lt;";"<")|
        gsub("&gt;";">")|
        gsub("&amp;";"&")|
        gsub("\n+";" br ")))|
    "xxbos "+.body
