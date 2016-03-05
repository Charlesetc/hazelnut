# generator/call_tree.rb

module Tree

  @@token_functions = {}
  @@stacks = [[]]

  def self.match(token, &block)
    @@token_functions[token] = block
  end

  match :if do |tree|
    raise "argument error: if takes one argument" if tree.arguments.length != 1
    raise "argument error: if takes a block" if tree.block.nil?
    output = [
      "if ",
      call(tree.arguments[0]),
      "{",
      generate_calls(tree.block.forest),
      "}",
    ].join
    self.if_statement = output
    output
  end

  match :else do |tree|
    raise "syntax error: else must follow an if" unless self.if_statement
    if tree.arguments.length == 0
      previous_if = self.if_statement
      self.if_statement = nil
      previous_if << [
        "else ",
        "{",
        generate_calls(tree.block.forest),
        "}",
      ].join
    else
      unless tree.arguments[0].symbol == :if
        raise "syntax error: else can only be followed by if or {"
      end
      tree.name = tree.arguments.shift.name
      self.if_statement << "else "
      self.if_statement << call(tree)
    end
    self.if_statement = nil
    ''
  end

  match :let do |tree|
    raise "let does not take a block" unless tree.block.nil?
    raise "let needs an even number of arguments" unless tree.arguments.length % 2 == 0

    tree.arguments.each_slice(2).map do |ident, value|
      raise "'let' takes identifier - expression pairs as arguments" unless ident.is_ident?

      if @@stacks.last.include?(ident.symbol)
        equals = "="
      else
        equals = ":="
        stack_push ident
      end

      [[ident.symbol, equals, call(value), "\n"].join,
       equals == ":=" ? ident.symbol.to_s : ""]
    end
  end

  def call(tree)
    function = @@token_functions[tree.symbol]
    return self.instance_exec(tree, &function) if function
    call_normal_function(tree)
  end

  def call_normal_function(tree)
    self.if_statement = nil

    if tree.is_ident? and @@stacks.flatten.include? tree.symbol
      return tree.symbol.to_s
    end
    [
      tree.symbol,
      "(",
      arguments(tree),
      ",",
      block(tree),
      ")",
    ].join
  end

  def stack_push(expression)
    @@stacks.last << expression.symbol
  end

  def arguments(tree)
    as = tree.arguments.reduce('') do |output, argument|
        output + call(argument) + ','
    end
    [
      "[]*any{",
      as,
      "}",
    ].join
  end

  def block(tree)
    return 'nil' if (
      tree.block.nil?
    )

    enter_stack
    output = generate_function("", tree.block.arguments, tree.block.forest, true)
    exit_stack
    return output
  end

  def enter_stack
    @@stacks << []
  end

  def exit_stack
    @@stacks.pop
  end

end