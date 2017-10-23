class InputElement
  attr_accessor :id, :owner, :amount

  def initialize(id, owner, amount)
    @id = id
    @owner = owner
    @amount = amount.to_i
  end
end
class OutputElement
  attr_accessor :owner, :amount

  def initialize(owner, amount)
    @owner = owner
    @amount = amount.to_i
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
end

def main
  input = []
  transactions = []
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

  transactions.sort_by!{|t| t.timestamp}

  executed_transactions = []
  transactions.each do |t|
    if t.valid?(executed_transactions)
      executed_transactions << t
    end
  end

  File.open("#{ARGV[0].split(".")[0]}-res.txt", 'w') do |file|
    file << executed_transactions.count.to_s + "\n"
    executed_transactions.each do |t|
      file << input_map[t] + "\n";
    end
  end
end

main()
