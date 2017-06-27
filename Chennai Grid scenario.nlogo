;
extensions [vid gis nw] ;extensions that Netlogo is using to run this model
breed [nodes node] ; NetLogo allows you to define different "breeds" of turtles and breeds of links. Once you have defined breeds, you can go on and make the different breeds behave differently. For example, you could have breeds called sheep and wolves, and have the wolves try to eat the sheep or you could have link breeds called streets and sidewalks where foot traffic is routed on sidewalks and car traffic is routed on streets.
undirected-link-breed [edges edge]

breed [fires fire]

nodes-own [
  key
  available-power
  actual-power
  search-parent
  search-costs-from-start
]

edges-own [
  capacity
  load
  life-time
]

fires-own [ ;fire appears to show that an edge (i.e a power line) has been disrupted in the simulation display
  fire-key1
  fire-key2
  fire-capacity
  fire-load
  fire-life-time
]

globals [cyclone-1 cyclone-2 mouse-first-node mouse-second-node search-open-node-list search-closed-node-list current-time is-grid-disrupted? is-grid-isolated? initial-number-of-edges _recording-save-file-name projection dataset chennai-dataset patch-area-sqkm] ;If a variable is a global variable, there is only one value for the variable, and every agent can access it. You can think of global variables as belonging to the observer.

to setup-globals
  set-default-shape nodes "circle"
  set-default-shape fires "fire"
  set mouse-first-node nobody
  set mouse-second-node nobody
  set current-time 0
  set is-grid-disrupted? false
  set is-grid-isolated? false
  set initial-number-of-edges 0
end

to startup
  setup
  let file "grid.dat" ;a map of the network reconstructed from the GRID MAP provided by TNEB
  if file-exists? file [ read-grid-data-from-file file ]
end

to setup
  clear-all
  setup-globals
  reset-ticks
  setup-fire

set projection "WGS_84_Geographic"

set chennai-dataset gis:load-dataset "/Users/balanarayanaswamy/wards.shp";edit file path with your computers' as required

 gis:set-world-envelope (gis:envelope-of chennai-dataset)

  gis:set-drawing-color white
  gis:draw chennai-dataset 1

  reset-ticks

end

to go
;  beep
;  user-message "The procedure 'go' is not implemented yet!"
;  stop
  if is-grid-isolated? or count edges = 0 or count nodes = 0 [ stop ]
  if ticks > 0
  [ go-failure-of-a-edge ]
   set initial-number-of-edges count edges
    numerize-nodes
  optimize-flow
  go-calculate-life-time-of-edges
  if data-output != "no" [ write-data-to-files ]
  tick
end

;; ============= Simulate network dynamics =================

to go-failure-of-a-edge


  min-one-of edges with [life-time > 0 ] [
    ask min-one-of edges with [life-time > 0 ] [life-time] [
      if output-level = 1 [ show "selected!" ]
      set current-time current-time + life-time
      go-create-fire-at-destroyed-edge
      die
  ]
end

to go-calculate-life-time-of-edges
  ask edges [
    ifelse load > 0
      [ set life-time random-exponential capacity / load ]
      [ set life-time -1 ]
  ]
end

to go-create-fire-at-destroyed-edge
  let x 0.5 * ( [xcor] of end1 + [xcor] of end2)
  let y 0.5 * ( [ycor] of end1 + [ycor] of end2)
  let key1 [key] of end1
  let key2 [key] of end2
  ask one-of fires [
    set xcor x
    set ycor y
    ifelse show-destroyed [ show-turtle ][ hide-turtle ]
    set fire-key1 key1
    set fire-key2 key2
    set fire-capacity [capacity] of myself
    set fire-load [load] of myself
  ]
end

to setup-fire
  create-fires 1 [
    set size 2
    set color white
    hide-turtle
    set fire-key1 -1
    set fire-key2 -1
    set fire-capacity -1
    set fire-load -1
  ]
end

;; ============= Draw nodes and edges ======================

to draw-structure
  ask nodes [ draw-node ]
  ask edges [ draw-edge ]
end

to draw-node
  ifelse actual-power != 0 [ set size 1 + log abs actual-power 10 ] [ set size 1 ]
  let power available-power
  ifelse is-dangling? [ set color yellow ] [ set color green ]
  ifelse power > 0 [ set color blue ] [set label "transformer"] ; the "source" node in Chennai's grid
  ifelse power < 0 [ set color red ][set label "powerplant"]  ;the "sink" node in Chennai's grid
end

to-report is-dangling?
  report count edges with [end1 = myself or end2 = myself] < 2
end

to draw-edge
  ifelse load > 0
  [
    set color green
    set thickness (1 - exp (- 0.5 * load))
    if load > capacity
    [
      ifelse load > 2 * capacity
      [
        ifelse load > 4 * capacity
        [ set color red ]
        [ set color orange ]
      ]
      [ set color yellow ]
    ]
  ]
  [
     set color grey
     set thickness (1 - exp (- 0.5 * capacity))
  ]
end

to numerize-nodes
  if any? nodes with [key < 0] [
    let counter 0
    ask nodes [
      set counter counter + 1
      set key counter
    ]
  ]
end

to-report edge-mean
  report mean [count my-edges] of nodes
end

to-report edge-variance
  report standard-deviation [count my-edges] of nodes
end

;;============== Design the net-structure ===================

to add-nodes
  setup-nodes
  setup-spatially-clustered-network
  draw-structure
end

to setup-nodes
  create-nodes number-of-nodes  [
    ; for visual reasons, we don't put any nodes *too* close to the edges
    setxy (random-xcor * 0.95) (random-ycor * 0.95)
    setup-node
  ]
end

to setup-node
    set available-power 0
    set actual-power 0
    set key -1
end

to setup-spatially-clustered-network
  let number-of-edges (average-node-degree * count nodes) / 2
  while [count edges < number-of-edges ]
  [
    ask one-of nodes [
      let choice ( min-one-of
        ( other nodes with [not edge-neighbor? myself] )
        [distance myself] )
      if choice != nobody [
        create-edge-with choice [
          set capacity 1
          set load 0
        ]
      ]
    ]
  ]
end

to add-power
  let total-power total-power-flux
  while [total-power > 0] [
    let power 1
    if random-type = "float" [ set power power +   random-float 2 ]
    if random-type = "integer" [ set power power +   random 2 ]
    if power > total-power [ set power total-power ]
    set total-power total-power - power
    ask one-of nodes with [available-power <= 0] [
      set available-power available-power - power
    ]
    ask one-of nodes with [available-power >= 0] [
      set available-power available-power + power
    ]
  ]
  draw-structure
end

to remove-power
  ask nodes [
    set available-power 0
    set actual-power 0
    draw-node
  ]
  ask edges [
    set load 0
    set capacity 1
    draw-edge
  ]
end

to-report edge-level
  let value 100.
  if initial-number-of-edges > 0 [
    set value 100.0 * count edges / initial-number-of-edges
  ]
  report value
end

to-report disrupted-level
  let value 0
  if is-grid-disrupted? [ set value 100 ]
  report value
end

;;============== Editing the nodes and edges =========

to-report select-nearest-node
  report one-of nodes with-min [distancexy mouse-xcor mouse-ycor]
end

to insert-node
  if mouse-down? and mouse-inside? [
    create-nodes 1 [
      setxy mouse-xcor mouse-ycor
      setup-node
      draw-node
    ]
    stop
  ]
end

to delete-node
  if mouse-down? and mouse-inside? [
    ask select-nearest-node [ die ]
    draw-structure
    stop
  ]
end

to move-node
  if mouse-down? and mouse-inside? [
    ask select-nearest-node [ setxy mouse-xcor mouse-ycor ]
    if not mouse-down? [ stop ]
  ]
end

to set-selected
  set size size * 2
end

to set-unselected
  set size size * 0.5
end

to insert-edge
  if mouse-first-node = nobody [
     if mouse-down? and mouse-inside? [
       set mouse-first-node select-nearest-node
       ask mouse-first-node [ set-selected ]
     ]
  ]
  if mouse-second-node = nobody or mouse-second-node = mouse-first-node [
    if mouse-down? and mouse-inside? [ set mouse-second-node select-nearest-node ]
  ]
  if mouse-first-node != nobody and mouse-second-node != nobody
  and mouse-second-node != mouse-first-node [
    ask mouse-first-node [
      set-unselected
      create-edge-with mouse-second-node [
          set capacity 1
          set load 0
        ]
    ]
    draw-structure
    set mouse-first-node nobody
    set mouse-second-node nobody
    stop
  ]
end

to-report edges-between [node1 node2]
  report edges with [end1 = node1 and end2 = node2]
end

to delete-edge
  if mouse-first-node = nobody [
     if mouse-down? and mouse-inside? [
       set mouse-first-node select-nearest-node
       ask mouse-first-node [ set-selected ]
     ]
  ]
  if mouse-second-node = nobody or mouse-second-node = mouse-first-node [
    if mouse-down? and mouse-inside? [ set mouse-second-node select-nearest-node ] ]
  let found-edges edges-between mouse-first-node mouse-second-node
  if any? found-edges [
    ask one-of found-edges [ die ]
    ask mouse-first-node [ set-unselected ]
    set mouse-first-node nobody
    set mouse-second-node nobody
    draw-structure
    stop
  ]
end

to increase-power
  if mouse-down? and mouse-inside? [
    ask select-nearest-node [
      set available-power available-power + 1
      draw-node
    ]
    stop
  ]
end

to decrease-power
  if mouse-down? and mouse-inside? [
    ask select-nearest-node [
      set available-power available-power - 1
      draw-node
    ]
    stop
  ]
end

to radial-layout
  if mouse-down? and mouse-inside? [
    layout-radial nodes edges select-nearest-node
    stop
  ]
end

to spring-layout
  let spring-force 1
  let spring-length world-width / (sqrt count nodes)
  let repulsion-force 1
  repeat 30 [ layout-spring nodes edges spring-force spring-length repulsion-force ]
end

to circle-layout
  let radius 0.4 * min (list world-width world-height)
  let node-set max-n-of 3 nodes [count edge-neighbors ]
  repeat 10 [ layout-tutte node-set edges radius ]
end

;;============== Save and load net-structure ===================

to write-data-to-files
  if data-output = "each" or data-output = "all" [
    let file-name (word "grid-sim-" ticks)
    let network-file (word file-name ".dat")
    if is-string? network-file [
      if file-exists? network-file [ file-delete network-file ]
      write-grid-data-to-file network-file
    ]
  ]
  if data-output = "for R" or data-output = "all" [ write-data-to-R-files ]
end

to write-data-to-R-files
  numerize-nodes
  let file-name (word "grid-nodes-R-" number-of-run ".dat")
  if ticks = 0 and file-exists? file-name [ file-delete file-name ]
  file-open file-name
  if ticks = 0 [ file-print "key current-time xcor ycor available-power actual-power" ]
  ask nodes [
    file-write key
    file-write current-time
    file-write xcor
    file-write ycor
    file-write available-power
    file-write actual-power
    file-print " "
  ]
  file-close
  set file-name (word "grid-edges-R-" number-of-run ".dat")
  if ticks = 0 and file-exists? file-name [ file-delete file-name ]
  file-open file-name
  if ticks = 0 [ file-print "key1 key2 current-time capacity load life-time deleted?" ]
  ask fires [
    if fire-key1 >= 0 [
      file-write fire-key1
      file-write fire-key2
      file-write current-time
      file-write fire-capacity
      file-write fire-load
      file-write fire-life-time
      file-print " 1 "
    ]
  ]
  ask edges [
    file-write [key] of end1
    file-write [key] of end2
    file-write current-time
    file-write capacity
    file-write load
    file-write life-time
    file-print " 0 "
  ]
  file-close
end

to-report check-file-name [file-name file-tag]
  if is-string? file-name [
    let found substring file-name (length file-name - length file-tag) length file-name
    if found != file-tag [ set file-name (word file-name file-tag)     ]
  ]
  report file-name
end

to save-grid
  let network-file check-file-name user-new-file ".dat"
  if is-string? network-file [
    if file-exists? network-file [ file-delete network-file ]
    write-grid-data-to-file network-file
  ]
end

to write-grid-data-to-file [network-file]
  numerize-nodes
  file-open network-file
  file-print count nodes
  file-print "* node data key label x y available-power actual-power"
  foreach sort-on [key] nodes  [ [?1] ->
    ask ?1 [
      if empty? label [ set label (word key)]
      file-write key
      file-write label
      file-write xcor
      file-write ycor
      file-write available-power
      file-write actual-power
      file-print " "
    ]
  ]
  file-print "* edge data key1 key2 capacity load"
  ask edges [
    file-write [key] of end1
    file-write [key] of end2
    file-write capacity
    file-write load
    file-print " "
  ]
  file-close
end

to load-grid
  setup
  let network-file user-file
  if is-string? network-file and file-exists? network-file [
    read-grid-data-from-file network-file
  ]
end

to read-grid-data-from-file [network-file]
  file-open network-file
  let counter file-read
  let dummy file-read-line
  while [counter > 0] [
    create-nodes 1 [
      set color green
      set key file-read
      set label file-read
      setxy file-read file-read
      set available-power file-read
      set actual-power file-read
    ]
    set counter counter - 1
  ]
  set dummy file-read-line
  while [not file-at-end? ] [
    let token file-read
    let next-token file-read
    let first-node one-of nodes with [key = token]
    let second-node one-of nodes with [key = next-token]
    ask first-node [
      create-edge-with second-node [
        set capacity file-read
        set load file-read
      ]
    ]
  ]
  file-close
  draw-structure
end

;;============== Export net-structure in various formats ===

to export
  numerize-nodes
  if format = "NET"
  [
    let network-file check-file-name user-new-file".net"
    if is-string? network-file [
      if file-exists? network-file [ file-delete network-file ]
      write-NET-data-to-file network-file
    ]
  ]
  if format = "VNA"
  [
    let network-file check-file-name user-new-file ".vna"
    if is-string? network-file [
      if file-exists? network-file [ file-delete network-file ]
      write-VNA-data-to-file network-file
    ]
  ]
  if format = "R"
  [
    let node-file check-file-name user-new-file ".nodes.imp"
    let edge-file (word (remove ".nodes.imp" node-file ) ".edges.imp")
    if is-string? node-file and is-string? edge-file [
      if file-exists? node-file [ file-delete node-file ]
      if file-exists? edge-file [ file-delete edge-file ]
      write-R-node-data-to-file node-file
      write-R-edge-data-to-file edge-file
    ]
  ]
end

to write-NET-data-to-file [network-file]
  file-open network-file
  file-type "*Vertices " file-print count nodes
  foreach sort-on [key] nodes  [ [?1] ->
    ask ?1 [
      file-write key
      file-write label
      file-write xcor
      file-write ycor
      file-print " "
    ]
  ]
  file-print "*Arcs"
  ask edges [
    file-write [key] of end1 file-type " "
    file-write [key] of end2 file-type " "
    file-write 1 + load
    file-print " "
  ]
  file-close
end

to write-VNA-data-to-file [network-file]
  file-open network-file
  file-print "*Node data"
  file-print "id available-power actual-power"
  foreach sort-on [key] nodes [ [?1] ->
    ask ?1 [
      if empty? label [ set label (word key)]
      file-write key
      file-write precision available-power 2
      file-write precision actual-power 2
      file-print " "
    ]
  ]
  let size-factor 10
  file-print "*Node properties"
  file-print "id x y color shape size shortlabel"
  let vshape 1
  foreach sort-on [key] nodes [ [?1] ->
    ask ?1 [
      file-write key
      file-write precision (size-factor * (xcor - min-pxcor)) 0
      file-write precision (size-factor * (ycor - min-pycor)) 0
      file-write integer-color
      file-write vshape
      file-write precision (size-factor * size) 0
      file-write label
      file-print " "
    ]
  ]
  file-print "*Tie data"
  file-print "from to strength load capapcity"
  ask edges [
    file-write [key] of end1
    file-write [key] of end2
    file-write 1
    file-write load
    file-write capacity
    file-print " "
    file-write [key] of end2
    file-write [key] of end1
    file-write 1
    file-write load
    file-write capacity
    file-print " "
  ]
  file-print "*Tie properties"
  file-print "from to color size headcolor headsize active"
  let headsize 0
  let active -1
  ask edges [
    let lcolor integer-color
    file-write [key] of end1
    file-write [key] of end2
    file-write lcolor
    file-write precision (size-factor * thickness) 0
    file-write lcolor
    file-write headsize
    file-write active
    file-print " "
    file-write [key] of end2
    file-write [key] of end1
    file-write lcolor
    file-write precision (size-factor * thickness) 0
    file-write lcolor
    file-write headsize
    file-write active
    file-print " "
  ]
  file-close
end

to write-R-node-data-to-file [network-file]
  file-open network-file
  file-print "key x y available actual"
  ask nodes [
    file-write key
    file-write xcor
    file-write ycor
    file-write available-power
    file-write actual-power
    file-print " "
  ]
  file-close
end

to write-R-edge-data-to-file [network-file]
  file-open network-file
  file-print "key1 key2 capacity load "
  ask edges [
    file-write [key] of end1
    file-write [key] of end2
    file-write capacity
    file-write load
    file-print " "
  ]
  file-close
end

to-report integer-color
  let value 0
  let color-list extract-rgb color
  let red-value item 0 color-list
  let green-value item 1 color-list
  let blue-value item 2 color-list
  set value red-value + 256 * green-value + 256 * 256 * blue-value
  report value
end

;;============== provide characteristic values for net-structure ==

to-report power-supply-level
  let value 0
  let total power-supply
  if total > 0 [
    set value 100.0 * power-input / total
  ]
  report value
end

to-report power-demand-level
  let value 0
  let total power-demand
  if total > 0 [
    set value 100.0 * power-output / total
  ]
  report value
end

to-report power-supply
  let power 0
  ask nodes with [available-power > 0] [
    set power power + available-power
  ]
  report power
end

to-report power-demand
  let power 0
  ask nodes with [available-power < 0] [
    set power power + available-power
  ]
  report power * -1
end

to-report power-input
  let power 0
  ask nodes with [available-power > 0] [
    set power power + actual-power
  ]
  report power
end

to-report power-output
  let power 0
  ask nodes with [available-power < 0] [
    set power power + actual-power
  ]
  report power * -1
end

to-report power-variance
  let value 0
  ask nodes [
    let delta available-power - actual-power
    set value value + delta * delta
  ]
  report sqrt value
end

to-report flux-variance
  let value 0
  ask edges [
    let delta capacity - load
    set value value + delta * delta
  ]
  report sqrt value
end

;; ================= Optimize the flux in net-structure ==========

to reset-structure
  ask nodes [
    set actual-power 0
    draw-node
  ]
  ask edges [
    set load 0
    draw-edge
  ]
end

to optimize-flow
  reset-structure
  let is-isolated? true
  let is-disrupted? false
  let targets nodes with [available-power < 0]
  ask targets [
    let sources nodes with [can-provide?]
    ask min-n-of (count sources) sources [distance myself] [
      if [is-needing?] of myself [
        set is-disrupted? not update-net-structure self myself
        set is-isolated? is-isolated? and is-disrupted?
        set is-grid-disrupted? is-disrupted? or is-grid-disrupted?
      ]
    ]
  ]
  set is-grid-isolated? is-isolated?
  draw-structure
end

to-report is-needing?
  report available-power < 0 and actual-power > available-power
end

to-report can-provide?
  report available-power > 0 and actual-power < available-power
end

to change-power [this-load]
  if available-power > 0 [ set actual-power actual-power + this-load ]
  if available-power < 0 [ set actual-power actual-power - this-load ]
end

to-report calculate-net-flow [start-node target-node]
  let this-flow  0
  ask start-node [
    set this-flow available-power - actual-power
  ]
  ask target-node [
    let that-flow actual-power - available-power
    if that-flow < this-flow [ set this-flow that-flow ]
  ]
  report this-flow
end

to change-flow-structure [start-node target-node edge-list this-load]
  if not empty? edge-list [
    ask start-node [
      change-power this-load
      draw-node
    ]
    ask target-node [
      change-power this-load
      draw-node
    ]
    foreach edge-list [ [?1] ->
      ask ?1 [
        set load load + this-load
        draw-edge
      ]
    ]
  ]
end

to-report update-net-structure [start-node target-node]
  let path-found? true
  let edge-list search-go start-node target-node
  let found-path? not empty? edge-list
  ifelse found-path?
  [
    let this-load calculate-net-flow start-node target-node
    if output-level = 1 [ show (word "Power flow: " this-load " with " (length edge-list)
      " edges between " start-node " and " target-node) ]
    if this-load > 0 [ change-flow-structure start-node target-node edge-list this-load ]
  ]
  [
    if output-level = 1 [ show (word "No path found between " start-node " and " target-node) ]
    set path-found? false
  ]
  report path-found?
end

to adjust-capacities
  ask edges [
    if load > capacity [ set capacity load ]
    draw-edge
  ]
end

to remove-unused
  ask edges with [load = 0] [ die ]
  ask nodes with [ count my-edges = 0] [die]
  draw-structure
end

to optimize-structure
  repeat optimize-steps [
    optimize-flow
    adjust-capacities
  ]
  optimize-flow
end

;; ================= Search shortest path in net-structure =======

to-report search-go [start-node target-node]
  let node-list search-path start-node target-node
  let edge-list search-transfer-node-list-to-edge-list node-list
  report edge-list
end

to-report search-path [start-node target-node]
  if output-level = 2 [ show ( word "Search path between " start-node " and " target-node ) ]
  let new-path ( list )
  search-init start-node
  if search-do target-node [
    set new-path search-path-back target-node
  ]
  report new-path
end

to search-init [ start-node ]
  if output-level = 2 [ show ( word "Init search from " start-node ) ]
  ask nodes [
    set search-parent nobody
    set search-costs-from-start 0
  ]
  set search-open-node-list fput start-node ( list )
  set search-closed-node-list ( list )
end

to-report search-rank
  report search-costs-from-start
end


to-report search-do [target-node]
  if output-level = 2 [ show ( word "Do search to " target-node ) ]
  let current-node nobody
  while [target-node != current-node] [
    if empty? search-open-node-list [
      if output-level = 2 [ show ( word "No path to " target-node ) ]
      report false
    ]
    ; remove lowest rank item from open list of patches and add it to the closed list
    set search-open-node-list sort-by [ [?1 ?2] -> [ search-rank ] of ?1 < [ search-rank ] of ?2 ] search-open-node-list
    set current-node first search-open-node-list
    set search-open-node-list but-first search-open-node-list
    set search-closed-node-list fput current-node search-closed-node-list
    if output-level = 2 [ show ( word "Current node " current-node ) ]
    ; check adjacent nodes
    if target-node != current-node [
      ask current-node [ search-handle-neighbors self target-node]
    ]
  ]
  if output-level = 2 [ show ( word "Found target " current-node ) ]
  report true
end

to search-handle-neighbors [parent-node target-node]
  ask my-edges [
    let costs [ search-costs-from-start ] of parent-node + 1
    if load > capacity [ set costs costs + over-capacity-costs ]
    ask other-end [
      if member? self search-open-node-list and costs < search-costs-from-start [
        set search-open-node-list remove self search-open-node-list
        if output-level = 2 [ show ( word "Neighbor node " self
            " removed from open " search-open-node-list ) ]
      ]
      if member? self search-closed-node-list and costs < search-costs-from-start [
        set search-closed-node-list remove self search-closed-node-list
        if output-level = 2 [ show ( word "Neighbor node " self
            " removed from closed " search-closed-node-list ) ]
      ]
      if ( not member? self search-open-node-list )
      and ( not member? self search-closed-node-list ) [
        if output-level = 2 [ show ( word "Neighbor node " self
            " with costs=" costs " to parent " parent-node ) ]
        set search-parent parent-node
        set search-costs-from-start costs
        set search-open-node-list fput self search-open-node-list
      ]
    ]
  ]
end

to-report search-path-back [target-node]
  let found-path fput target-node ( list )
  let current-node target-node
  if output-level = 2 [ show ( word "Revert search " current-node ) ]
  while [ [ search-parent ] of current-node != nobody ] [
    set current-node [ search-parent ] of current-node
    set found-path fput current-node found-path
    if output-level = 2 [ show ( word "Revert search " current-node ) ]
  ]
  report found-path
end

to-report search-edge-for-nodes [that-node this-node]
  report one-of edges with [ (end1 = that-node and end2 = this-node)
    or (end2 = that-node and end1 = this-node) ]
end

to-report search-transfer-node-list-to-edge-list [node-list]
  let edge-list (list)
  let last-node nobody
  foreach node-list [ [?1] ->
    let current-node ?1
    if last-node != nobody [
      let found-edge search-edge-for-nodes current-node last-node
      if output-level = 2 [ show (word "Found " found-edge " of " current-node " " last-node) ]
      set edge-list fput found-edge edge-list
    ]
    set last-node current-node
  ]
  report edge-list
end

;; ============== plotting ===========================


to plot-histogram-of [that-distribution]
  ifelse length that-distribution > 0 [
    let x-max ( ceiling max that-distribution )
    if x-max <= 0 [ set x-max 1.0 ]
    let y-max length that-distribution
    set-plot-x-range 0 x-max
    set-plot-y-range 0 y-max
    set-histogram-num-bars 20
    histogram that-distribution
  ] [
    clear-plot
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
284
10
702
429
-1
-1
10.0
1
10
1
1
1
0
0
0
1
-20
20
-20
20
0
0
1
ticks
30.0

BUTTON
7
165
104
198
NIL
insert-node
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
6
10
67
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
7
200
105
233
NIL
delete-node
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
7
234
105
267
NIL
move-node
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
107
165
205
198
NIL
insert-edge
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
107
200
205
233
NIL
delete-edge
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
794
233
880
266
radial layout
radial-layout
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
108
235
206
268
NIL
spring-layout
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
708
233
793
266
NIL
circle-layout
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
86
95
243
128
number-of-nodes
number-of-nodes
10
200
100.0
5
1
NIL
HORIZONTAL

SLIDER
7
129
204
162
average-node-degree
average-node-degree
1
number-of-nodes - 1
30.0
1
1
NIL
HORIZONTAL

BUTTON
7
95
84
128
NIL
add-nodes
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
778
199
845
232
NIL
save-grid
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
709
199
775
232
NIL
load-grid
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
707
10
774
55
# nodes
count nodes
17
1
11

MONITOR
778
10
841
55
# edges
count edges
17
1
11

MONITOR
707
57
775
102
# sources
count nodes with [available-power > 0]
17
1
11

MONITOR
777
58
840
103
# sinks
count nodes with [available-power < 0]
17
1
11

BUTTON
6
312
120
345
NIL
increase-power
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
121
312
240
345
NIL
decrease-power
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
817
272
879
305
NIL
export
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
69
10
132
43
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
134
10
197
43
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
711
360
804
405
NIL
power-input
10
1
11

MONITOR
809
360
900
405
NIL
power-output
10
1
11

MONITOR
710
408
803
453
NIL
power-variance
6
1
11

MONITOR
807
408
900
453
NIL
flux-variance
6
1
11

BUTTON
6
381
138
414
NIL
optimize-flow
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
70
278
187
311
total-power-flux
total-power-flux
1
number-of-nodes
66.0
1
1
NIL
HORIZONTAL

BUTTON
7
278
68
311
NIL
add-power
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
6
346
121
379
NIL
remove-power
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
4
456
136
489
NIL
adjust-capacities
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
4
490
136
523
NIL
remove-unused
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
146
456
259
501
NIL
current-time
10
1
11

PLOT
262
456
457
606
Life Times
life time
# edges
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "plot-histogram-of ( [ life-time ] of edges with [life-time > 0] )"

MONITOR
710
107
800
152
# critical edges
count edges with [capacity < load]
17
1
11

MONITOR
145
550
258
595
NIL
is-grid-disrupted?
17
1
11

MONITOR
146
503
258
548
NIL
is-grid-isolated?
17
1
11

MONITOR
808
313
900
358
NIL
power-demand
4
1
11

MONITOR
710
313
804
358
NIL
power-supply
4
1
11

PLOT
460
456
709
606
Power Supply Flow
time
%
0.0
1.0
0.0
100.0
true
true
"" ""
PENS
"% input" 1.0 0 -13345367 true "" "plotxy current-time power-supply-level"
"% output" 1.0 0 -2674135 true "" "plotxy current-time power-demand-level"
"% edges" 1.0 0 -10899396 true "" "plotxy current-time edge-level"
"disrupted?" 1.0 0 -7500403 true "" "plotxy current-time disrupted-level"

BUTTON
122
346
241
379
remove-labels
ask nodes [ set label \"\" ]\nask fires [ hide-turtle ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
804
106
870
151
# dangles
count nodes with [color = yellow]
17
1
11

SLIDER
80
44
235
77
movie-ticks
movie-ticks
0
500
200.0
10
1
NIL
HORIZONTAL

BUTTON
6
44
79
77
movie
set _recording-save-file-name \"power-grid.mov\" vid:start-recorder\nvid:record-view ;; show the initial state\nrepeat movie-ticks\n[ go\n  vid:record-view ]\nvid:save-recording _recording-save-file-name
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
710
153
787
198
edge-mean
edge-mean
6
1
11

MONITOR
789
153
870
198
NIL
edge-variance
6
1
11

SWITCH
711
553
839
586
show-destroyed
show-destroyed
0
1
-1000

SLIDER
6
414
178
447
over-capacity-costs
over-capacity-costs
0
100
0.0
1
1
NIL
HORIZONTAL

BUTTON
4
525
136
558
NIL
optimize-structure
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
3
559
139
592
optimize-steps
optimize-steps
0
10
10.0
1
1
NIL
HORIZONTAL

CHOOSER
711
469
803
514
data-output
data-output
"no" "for R" "each" "all"
0

SLIDER
712
516
804
549
output-level
output-level
0
2
0.0
1
1
NIL
HORIZONTAL

INPUTBOX
805
474
901
534
number-of-run
1.0
1
0
Number

CHOOSER
711
267
803
312
format
format
"NET" "VNA" "R"
2

CHOOSER
189
269
281
314
random-type
random-type
"float" "integer"
1

@#$#@#$#@
# The Dynamics of Power-Grid Degradation

Thomas Rieth
IABG mbH, Einsteinstraße 20, D-85521 Ottobrun, Germany
rieth(at)iabg.de

## WHAT IS IT?

This application can be used for editing and simulating the stability of power-grids. Here, a power-grid is build by nodes that are connected by edges, and power is transfered from sources to sinks using the provided network.


## HOW IT WORKS

### The Structure of the Network

The power-grid here is build from a set of nodes that are connected by edges. Some of the nodes are either sources or sinks of power. The sign of the values of actual and available power specify the type of node:

  * connecting node (green) with `available-power = 0`
  * dangling nodes (yellow), i.e., nodes just connected by a single edge to the network
  * power sources (blue) with `available-power > 0`
  * power sinks (red) with `available-power < 0`

The size of power sources or sinks is given by a logarithmic scale:

    set size 1 + log abs actual-power 10

The edges are characterized by an actual load and a capacity they can carry. The thickness of edges is given by:

    if load > 0
    [ set thickness (1 - exp (- load)) ]
    [ set thickness (1 - exp (- capacity)) ]

The color indicates if the actual load exceeds the capacity:

  * _grey_ in case `load = 0`
  * _green_ if `0 < load < capacity`
  * _yellow_ for `capacity < load < 2 * capacity`
  * _orange_ for `2 * capacity < load < 4 * capacity`
  * _red_ for `load > 4 * capacity`

### The Dynamic of the Network

The dynamic behaviour of the network starts with an optimisation of the flow in the network.

    let is-isolated? true
    let targets nodes with [available-power < 0]
    ask targets [
      let sources nodes with [can-provide?]
      ask min-n-of (count sources) sources [distance myself] [
        if [is-needing?] of myself [
          set is-grid-disrupted? not update-net-structure self myself
          set is-isolated? is-isolated? and is-grid-disrupted?
        ]
      ]
    ]

For optimisation of the power flow an A<sup>*</sup> (A-star) search algorithm is used. The costs of an edge are given by the value one. If the load of a used edge exceeds its capacity, then additional costs are considered.

Depending on the power flow and the capacity of the edges their life-time is calculated using a random-exponential distribution.

    ask edges [
      ifelse load > 0
        [ set life-time random-exponential capacity / load ]
        [ set life-time -1 ]
    ]

During a simulation tick the simulation time (see the **current-time** monitor) is increased to next smallest life-time, and the respective edge is removed from the network. Then the network is optimised again, and the life-times of the edges in the new network are calculated repeatedly.

The simulation continues until either all edges or nodes are removed or all sources and sinks are seperated from each other, i.e., any flow is impossible between sources and sinks (see the monitor **is-grid-isolated?**)

The monitor **is-grid-disrupted** becomes true, whenever the search algorithm is unable to find a connection between one of the source and one of the sinks. One should notice that the network might have divided into two unconnected components quite earlier.

## HOW TO USE IT

During startup the application tries to read the file `grid.dat` if it exists. Pressing **setup** a blank scenario is created.

The data of the power-grid can be stored in files using the buttons **save-grid** or **load-grid**.

An export of the power-grid data in special network file formats is possible. Currently supported format are:

  1. Netdraw VNA format: The VNA format is commonly used by Netdraw, and is very similar to Pajek format. It defines nodes and edges (ties), and supports attributes.
  2. Pajek NET Format: This format use NET extension and is easy to use. Attributes support is however missing, only the network topology can be currently represented with a Pajek File.

### Layout of the Network
By pressing **add-nodes** further nodes are added randomly to the network. The number of these newly added nodes is set by the slider _number-of-nodes_. The algorithm connects all nodes with edges randomly. The number of edges is specified by the _average-node-degree_ slider.

Nodes and edges can be inserted or deleted by pressing the buttons and selecting one or two nodes using the mouse.

The monitors on the right side provide information about the number of nodes, edges, sources, sinks, and dangles.

Nodes can be moved using the **move-node** button. The **spring-layout** - as well as the **circle-layout** and the **radial-layout** button (you have to selct the central nodes using the mouse) - can be used to distribute the nodes in the network in a more uniform layout.

### Adding Sources and Sinks
A power-grid created initially has nowhere power flowing from sources to sinks. Here the load on all edges is zero, as well as the actual power of sources or sinks. During optimization shortest paths are searched between randomly chosen combination of power sources and sinks, and the power flow is put as an additional load onto edges. The actual power of sources or sinks is increased or decreased accordingly.

By pressing **add-power** sources and sinks of varying size are randomly put into the power grid. The slider _total-power-flux_ specifies the dimension of the additional power-flow.

Individual nodes can be changed by pressing either **increase-power** or **decrease-power** first, and then by selecting a node. The available power will be changed by a value of one.

The monitors (right side) show:

  1. _power-input_: the total available power input into network
  2. _power-output_:the total available power output from the network
  3. _power-variance_: a measure of difference between available and actual power supply and demand in all nodes
  4. _flux-variance_: a measure of difference between load and capacity of all edges
  5. _edge-mean_: the mean value of the edges' distribution
  6. _edge_variance_: the standard deviation of the edges' distribution

> power-variance = sqrt ( sum over all nodes ( available - actual power)<sup>2</sup>)
> flux-variance = sqrt ( sum over all edges ( load - capacity)<sup>2</sup>)

By pressing **remove-power** all power sources and sinks are removed, and they will change to standard connecting nodes (green). The load and capacity of the edges will be set to standard `load = 0 ` and `capacity = 1`.

By pressing **remove-labels** all labels on the nodes are removed, but whenever the network is saved, then new labels will be calculated.

### Optimization of the Network
The power-flow in the network can be optimized in three steps:

  1. **optimize-flow**: find the paths of the flow between power sources and sinks in the network. With the _over-capacity-costs_ sliders the additional costs for edges with load greater than their capacity can be set.
  2. **remove-unused**: remove edges with no load and nodes without any connecting edges
  3. **adjust-capacities**: change the edges' capacities to their current load (all edges will become gray)
  4. **optimize-structure**: the procedures `optimize-flow` and `adjust-structure` are repeated _optimize-steps_ times.

### Simulation of the Network
The simulation is started with:

  1. **go** will start the simulation of the degrading network.
  2. **step** allows to perform just a single simulation step until the next tick.

The following switches may be used:

  * _data-output_ : after every simulation step (tick) the resulting grid will be stored
    * in a file with name "grid-sim-_tick#_.dat" when set to _"each"_ or _"all"_
    * in files "grid-nodes-R-_number-of-run_.dat" and "grid-edges-R-_number-of-run_.dat" when set to _"for R"_ or _"all"_
  * _number-of-run_ : the counter for the output. This number can be used in NetLogo's Behavior Space to produce varying output files.
  * _output-level_: print more or less detailed informations about the A<sup>*</sup>-search algorithm into NetLogo's Command Center (a level of zero has no output)
  * _show-destroyed_ : whenever an edge is removed from the network, a fire symbol will be placed at the middle between the edge's both nodes for the duration of the tick. By pressing the _remove-labels_ button the symbol is removed, too.

A movie can be produced by pressing the **movie** button. The simulation will run for so many ticks as set with the _movie-ticks_ slider.

## THINGS TO NOTICE

Usually, the counting of (simulation) ticks corresponds to physical time. Here the physical time of the model is described by the variable monitor **current-time**. Whenever in the simulation an edge collapsed (is destroyed) after a randomly determined life-time, the tick counter of the simulation is increased by one.

Somehow, by unknown reasons, inserting and deleting edges does not always work properly in dense networks.

## THINGS TO TRY

Suggested things for the user to try to do (move sliders, switches, etc.) with the model are whatever the user wants.

## EXTENDING THE MODEL

Calculation of centrality measure might be a good help for the identification of important nodes in the network.


## NETLOGO FEATURES

The network, link, and mouse features from netlogo are heavily used.

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

Amit Patel. Introduction to A<sup>*</sup>. From Amit’s Thoughts on Pathfinding. http://theory.stanford.edu/~amitp/GameProgramming/AStarComparison.html (11 July 2014)

Wikipedia, the free encyclopedia. A<sup>*</sup> search algorithm. http://en.wikipedia.org/wiki/A*_search_algorithm (11 July 2014)

Wilensky, U. 1999. NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University. Evanston, IL
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fire
false
0
Polygon -7500403 true true 151 286 134 282 103 282 59 248 40 210 32 157 37 108 68 146 71 109 83 72 111 27 127 55 148 11 167 41 180 112 195 57 217 91 226 126 227 203 256 156 256 201 238 263 213 278 183 281
Polygon -955883 true false 126 284 91 251 85 212 91 168 103 132 118 153 125 181 135 141 151 96 185 161 195 203 193 253 164 286
Polygon -2674135 true false 155 284 172 268 172 243 162 224 148 201 130 233 131 260 135 282

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Monte Carlo experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup
read-grid-data-from-file "grid.dat"</setup>
    <go>go</go>
    <metric>power-supply-level</metric>
    <steppedValueSet variable="number-of-run" first="1" step="1" last="100"/>
    <enumeratedValueSet variable="show-destroyed">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="data-output">
      <value value="&quot;for R&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="optimize-steps">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="movie-ticks">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-power-flux">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-level">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="over-capacity-costs">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
