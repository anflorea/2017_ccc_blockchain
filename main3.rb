class InputElement
  attr_accessor :id, :owner, :amount

  def initialize(id, owner, amount)
    @id = id
    @owner = owner
    @amount = amount.to_i
  end

  def output_format
    str = ""
    str += id + " "
    str += owner + " "
    str += amount.to_s
    str
  end
end
class OutputElement
  attr_accessor :owner, :amount, :used

  def initialize(owner, amount)
    @owner = owner
    @amount = amount.to_i
    @used = false
  end

  def output_format
    str = ""
    str += owner + " "
    str += amount.to_s
    str
  end
end

class Transaction
  attr_accessor :id, :inputs, :outputs, :timestamp

  def initialize(transaction_id, inputs, outputs, timestamp)
    @id = transaction_id
    @inputs = inputs
    @outputs = outputs
    @timestamp = timestamp.to_i
  end

  def valid?(validated_transactions)
    input_sum = inputs.map(&:amount).inject(0){|res, am| res += am}
    output_sum = outputs.map(&:amount).inject(0){|res, am| res += am}
    return false if input_sum != output_sum #1. Sum of input amounts must match sum of output amounts
    return true if inputs.count == 1 && inputs.first.owner == "origin" && outputs.count == 1 #2 Except initial funding that comes from origin
    return false if outputs.map(&:owner).uniq.count != outputs.map(&:owner).count #3 An owner is only allowed to be listed once in the transaction output elements of a single transaction.
    return false if inputs.map{|i| [i.id, i.owner]}.uniq.count != inputs.map{|i| [i.id, i.owner]}.count
    return false if outputs.count == 0
    return false if inputs.count == 0

    inputs.each do |input_element|
      validated_input_transaction = validated_transactions.find{|t| t.id == input_element.id}
      return false if validated_input_transaction.nil? # 4.Any other funding must have been the output of a valid previous transaction, that is mentioned in the input file
      validated_output = validated_input_transaction.outputs.select{|output| output.amount == input_element.amount && output.owner  == input_element.owner}
      return false if validated_output.count != 1 # 5. Input elements need to be spent completely / One transaction output element can only be used once for input
    end

    return false if inputs.map(&:amount).select{|am| am <= 0}.count > 0
    return false if outputs.map(&:amount).select{|am| am <= 0}.count > 0

    return true
  end

  def output_format
    str = ""
    str += id + " "
    str += inputs.count.to_s + " "
    str += inputs.map(&:output_format).join(" ") + " "
    str += outputs.count.to_s + " "
    str += outputs.map(&:output_format).join(" ") + " #{timestamp}\n"
    str
  end
end

class TransactionRequest
  attr_accessor :id, :from, :to, :amount, :timestamp

  def initialize(id, from, to, amount, timestamp)
    @id = id
    @from = from
    @to = to
    @amount = amount.to_i
    @timestamp = timestamp.to_i
  end
end

def main
  input = []
  transactions = []
  requests = []
  input_map = {}

  File.open(ARGV[0], 'r') do |file|
    file.each_line do |line|
      input << line
    end
  end

  input.reverse!

  num_transactions = input.pop.to_i
  (0...num_transactions).to_a.each do
    transaction_data = input.pop.split(" ")
    id = transaction_data[0]
    inputs = []
    outputs = []
    cur_idx = 2


    num_inputs = transaction_data[1].to_i
    num_inputs.times do |i|
      input_id = transaction_data[cur_idx]
      cur_idx += 1
      input_owner = transaction_data[cur_idx]
      cur_idx += 1
      amount = transaction_data[cur_idx]
      cur_idx += 1
      inputs << InputElement.new(input_id, input_owner, amount)
    end

    num_outputs = transaction_data[cur_idx].to_i
    cur_idx += 1
    num_outputs.times do |i|
      output_owner = transaction_data[cur_idx]
      cur_idx += 1
      amount = transaction_data[cur_idx]
      cur_idx += 1
      outputs << OutputElement.new(output_owner, amount)
    end

    timestamp = transaction_data[cur_idx]
    transaction = Transaction.new(id, inputs, outputs, timestamp)
    input_map[transaction] = transaction_data.join(" ")
    transactions << transaction
  end

  num_requests = input.pop.to_i
  (0...num_requests).to_a.each do
    request_data = input.pop.split(" ")
    requests << TransactionRequest.new(request_data[0], request_data[1], request_data[2], request_data[3], request_data[4])
  end

  transactions.sort_by!{|t| t.timestamp}
  requests.sort_by!{|r| r.timestamp}

  executed_transactions = []
  transactions.each do |t|
    if t.valid?(executed_transactions)
      executed_transactions << t
    end
  end

  all_inputs_ids = executed_transactions.map{|t| t.inputs.map(&:id)}.flatten
  available_transactions = executed_transactions.select{|t| !all_inputs_ids.include? t.id }.sort_by{|t| t.timestamp}

  puts available_transactions.map(&:output_format)
  puts "---------------------------------------\n\n\n\n"

  ####
  requests.each do |r|
    next if r.amount <= 0 || r.to == r.from
    from = r.from
    available_from = available_transactions.select{|t| t.outputs.select{|o| !o.used }.map(&:owner).include? from}.sort_by{|t| t.timestamp}.reverse
    amount = r.amount
    used_transactions = []
    while amount > 0 && !available_from.empty?
      transaction = available_from.pop
      used_transactions << transaction
      amount -= transaction.outputs.select{|o| o.owner == from }.inject(0){|res, o| res += o.amount}
    end

    next if available_from.empty? && amount > 0 || used_transactions.empty?

    new_trans = Transaction.new(r.id, [], [], r.timestamp)
    used_transactions.each do |t|
      t.outputs.select{|o| o.owner == from }.each do |o|
        o.used = true
        new_trans.inputs << InputElement.new(t.id, o.owner, o.amount)
      end
    end

    new_trans.outputs << OutputElement.new(r.to, r.amount)
    if amount < 0
      new_trans.outputs << OutputElement.new(r.from, -amount)
    end

    available_transactions -= used_transactions.select{|t| t.outputs.count == t.outputs.select{|o| o.used == true}.count}
    available_transactions << new_trans
    if new_trans.valid?(executed_transactions)
      executed_transactions << new_trans
    end

    puts available_transactions.map(&:output_format)
    puts "---------------------------------------"
  end
  ####

  File.open("#{ARGV[0].split(".")[0]}-res.txt", 'w') do |file|
    file << executed_transactions.count.to_s + "\n"
    executed_transactions.each do |t|
      file << t.output_format;
    end
  end
end

main()
