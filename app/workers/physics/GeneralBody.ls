Vector = Box2D.Common.Math.b2Vec2

{b2BodyDef, b2FixtureDef} = Box2D.Dynamics
{b2PolygonShape, b2CircleShape} = Box2D.Collision.Shapes

module.exports = class GeneralBody
  (def, @uid, @scale) ->
    @bd = new b2BodyDef!
    @def = def
    if def.width is 0 then def.width = 1
    if def.height is 0 then def.height = 1

  initialize: ->
    {def, bd, scale} = @

    @data = def.{}data

    bd.position.Set def.x / scale, def.y / scale

    @fds = []

    newFixture = ~>
      fd = new b2FixtureDef!
      fd <<< density: 1, friction: 0.7, restitution: 0.3

      if @data.sensor is true then fd.is-sensor = true

      @fds[*] = fd

    create-shape = (def, position=false) ~>
      def = _.defaults def, GeneralBody::def-defaults

      switch def.type
        when "circle"
          fd = newFixture!
          fd.shape = new b2CircleShape def.radius / scale
          def.width = def.height = def.radius

          if position then new Vector def.x / scale, def.y / scale |> fd.shape.SetLocalPosition

        when "rect"
          fd = newFixture!
          fd.shape = new b2PolygonShape!
          if position
            fd.shape.SetAsOrientedBox def.width / scale / 2, def.height / scale / 2, (new Vector def.x / scale, def.y / scale), 0
          else
            fd.shape.SetAsBox def.width / scale / 2, def.height / scale / 2


        when "compound"
          for shape in def.shapes => create-shape shape, true

    create-shape def

    {@ids} = def

  attach-to: (world) ~>
    body = world.world.CreateBody @bd
    for fd in @fds => body.CreateFixture fd
    body.SetUserData @
    @ <<< {world, body}

  destroy: ~>
    if @world? then @world.world.DestroyBody @body

  halt: ~>
    @body.SetAngularVelocity 0
    @body.SetLinearVelocity new Vector 0, 0

  reset: ~>
    @halt!
    @position x:0, y: 0
    @angle 0

  is-awake: ~> @body.GetType! isnt 0 and @body.IsAwake!

  position: (p) ~>
    if p?
      new Vector (p.x + @def.x) / @scale, (p.y + @def.y) / @scale |> @body.SetPosition
    else
      p = @body.GetPosition!
      return x: (p.x * @scale) - @def.x, y: (p.y * @scale) - @def.y

  position-uncorrected: ~>
    p = @body.GetPosition!
    x: p.x * @scale, y: p.y * @scale

  absolute-position: ~> @position-uncorrected!

  angle: (a) ~> if a? then @body.SetAngle a else @body.GetAngle!

  angular-velocity: ~> @body.GetAngularVelocity!

  apply-torque: (n) ~> @body.ApplyTorque n

  defDefaults:
    x: 0
    y: 0
    width: 1
    height: 1
    radius: 0
    type: 'rect'
