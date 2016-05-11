require 'test_helper'

class MiniRacerTest < Minitest::Test

  def test_that_it_has_a_version_number
    refute_nil ::MiniRacer::VERSION
  end

  def test_it_can_eval_int
    context = MiniRacer::Context.new
    assert_equal 2, context.eval('1+1')
  end

  def test_it_can_eval_string
    context = MiniRacer::Context.new
    assert_equal "1+1", context.eval('"1+1"')
  end

  def test_it_returns_runtime_error
    context = MiniRacer::Context.new
    exp = nil

    begin
      context.eval('var foo=function(){boom;}; foo()')
    rescue => e
      exp = e
    end

    assert_equal MiniRacer::JavaScriptError, exp.class

    assert_match(/boom/, exp.message)
    assert_match(/foo/, exp.backtrace[0])
    assert_match(/mini_racer/, exp.backtrace[2])

    # context should not be dead
    assert_equal 2, context.eval('1+1')
  end

  def test_it_can_stop
    context = MiniRacer::Context.new
    exp = nil

    begin
      Thread.new do
        sleep 0.001
        context.stop
      end
      context.eval('while(true){}')
    rescue => e
      exp = e
    end

    assert_equal MiniRacer::JavaScriptError, exp.class
    assert_match(/terminated/, exp.message)

  end

  def test_it_can_automatically_time_out_context
    # 2 millisecs is a very short timeout but we don't want test running forever
    context = MiniRacer::Context.new(timeout: 2)
    assert_raises do
      context.eval('while(true){}')
    end
  end

  def test_it_handles_malformed_js
    context = MiniRacer::Context.new
    assert_raises do
      context.eval('I am not JavaScript {')
    end
  end

  def test_floats
    context = MiniRacer::Context.new
    assert_equal 1.2, context.eval('1.2')
  end

  def test_it_remembers_stuff_in_context
    context = MiniRacer::Context.new
    context.eval('var x = function(){return 22;}')
    assert_equal 22, context.eval('x()')
  end

  def test_can_attach_functions
    context = MiniRacer::Context.new
    context.attach("adder", proc{|a,b| a+b})
    assert_equal 3, context.eval('adder(1,2)')
  end

  def test_es6_arrow_functions
    context = MiniRacer::Context.new
    assert_equal 42, context.eval('adder=(x,y)=>x+y; adder(21,21);')
  end

  def test_concurrent_access
    context = MiniRacer::Context.new
    context.eval('counter=0; plus=()=>counter++;')

    (1..10).map do
      Thread.new {
        context.eval("plus()")
      }
    end.each(&:join)

    assert_equal 10, context.eval("counter")
  end

  def test_attached_exceptions
    context = MiniRacer::Context.new
    context.attach("adder", proc{raise StandardError})
    assert_raises do
      context.eval('adder(1,2,3)')
    end
  end

end
