#
# This file was used for TDD and as such probably has limited utility as
# actual unit tests.
#

osc = require "../lib/osc-utilities"

# Basic string tests.

testString = (str, expected_len) ->
    str : str
    len : expected_len
    
testData = [
    testString("abc", 4)
    testString("abcd", 8)
    testString("abcde", 8)
    testString("abcdef", 8)
    testString("abcdefg", 8)
]

testStringLength = (str, expected_len, test) ->
    oscstr = osc.toOscString(str)
    test.strictEqual(oscstr.length, expected_len)

exports["basic strings length"] = (test) ->
    for data in testData
        testStringLength data.str, data.len, test
    test.done()

testStringRoundTrip = (str, test, strict) ->
    oscstr = osc.toOscString(str)
    str2 = osc.fromOscString(oscstr, strict)
    test.strictEqual(str, str2)
    
exports["basic strings round trip"] = (test) ->
    for data in testData
        testStringRoundTrip data.str, test
    test.done()
    
exports["non strings fail toOscString"] = (test) ->
    test.strictEqual(osc.toOscString(7), null)
    test.done()
    
exports["strings with null characters don't fail toOscString by default"] = (test) ->
    test.notEqual(osc.toOscString("\u0000"), null)
    test.done()
    
exports["strings with null characters fail toOscString in strict mode"] = (test) ->
    test.strictEqual(osc.toOscString("\u0000", true), null)
    test.done()
    
exports["osc buffers with no null characters fail fromOscString in strict mode"] = (test) ->
    test.strictEqual(osc.fromOscString(new Buffer("abc"), true), null)
    test.done()

exports["osc buffers with non-null characters after a null character fail fromOscString in strict mode"] = (test) ->
    test.strictEqual(osc.fromOscString(new Buffer("abc\u0000abcd"), true), null)
    test.done()

exports["basic strings pass fromOscString in strict mode"] = (test) ->
    for data in testData
        testStringRoundTrip data.str, test, true
    test.done()

exports["osc buffers with non-four length fail in strict mode"] = (test) ->
    test.strictEqual(osc.fromOscString(new Buffer("abcd\u0000\u0000"), true), null)
    test.done()
    
exports["splitOscString of an osc-string matches the string"] = (test) ->
    split = osc.splitOscString osc.toOscString "testing it"
    test.strictEqual(split?.string, "testing it")
    test.strictEqual(split?.rest?.length, 0)
    test.done()

exports["splitOscString works with an over-allocated buffer"] = (test) ->
    buffer = osc.toOscString "testing it"
    overallocated = new Buffer(16)
    buffer.copy(overallocated)
    split = osc.splitOscString overallocated
    test.strictEqual(split?.string, "testing it")
    test.strictEqual(split?.rest?.length, 4)
    test.done()
    
exports["splitOscString works with just a string by default"] = (test) ->
    split = osc.splitOscString (new Buffer "testing it")
    test.strictEqual(split?.string, "testing it")
    test.strictEqual(split?.rest?.length, 0)
    test.done()
    
exports["splitOscString strict fails for just a string"] = (test) ->
    split = osc.splitOscString (new Buffer "testing it"), true
    test.strictEqual split, null
    test.done()

exports["splitOscString strict fails for string with not enough padding"] = (test) ->
    split = osc.splitOscString (new Buffer "testing \u0000\u0000"), true
    test.strictEqual split, null
    test.done()

exports["splitOscString strict succeeds for strings with valid padding"] = (test) ->
    split = osc.splitOscString (new Buffer "testing it\u0000\u0000aaaa"), true
    test.strictEqual(split?.string, "testing it")
    test.strictEqual(split?.rest?.length, 4)
    test.done()

exports["splitOscString strict fails for string with invalid padding"] = (test) ->
    split = osc.splitOscString (new Buffer "testing it\u0000aaaaa"), true
    test.strictEqual split, null
    test.done()
    
exports["fromOscMessage with no type string works"] = (test) ->
    translate = osc.fromOscMessage osc.toOscString "/stuff"
    test.strictEqual translate?.address, "/stuff"
    test.deepEqual translate?.arguments, []
    test.done()
    
exports["fromOscMessage with type string and no arguments works"] = (test) ->
    oscaddr = osc.toOscString "/stuff"
    osctype = osc.toOscString ","
    oscmessage = new Buffer(oscaddr.length + osctype.length)
    oscaddr.copy oscmessage
    osctype.copy oscmessage, oscaddr.length
    translate = osc.fromOscMessage oscmessage
    test.strictEqual translate?.address, "/stuff"
    test.deepEqual translate?.arguments, []
    test.done()
    
exports["fromOscMessage with string argument works"] = (test) ->
    oscaddr = osc.toOscString "/stuff"
    osctype = osc.toOscString ",s"
    oscarg = osc.toOscString "argu"
    translate = osc.fromOscMessage osc.concatenateBuffers [oscaddr, osctype, oscarg]
    test.strictEqual translate?.address, "/stuff"
    test.strictEqual translate?.arguments?[0]?.type, "string"
    test.strictEqual translate?.arguments?[0]?.value, "argu"
    test.done()
    
exports["fromOscMessage with blob argument works"] = (test) ->
    oscaddr = osc.toOscString "/stuff"
    osctype = osc.toOscString ",b"
    oscarg = osc.concatenateBuffers [(osc.toIntegerBuffer 4), new Buffer "argu"]
    translate = osc.fromOscMessage osc.concatenateBuffers [oscaddr, osctype, oscarg]
    test.strictEqual translate?.address, "/stuff"
    test.strictEqual translate?.arguments?[0]?.type, "blob"
    test.strictEqual (translate?.arguments?[0]?.value?.toString "utf8"), "argu"
    test.done()
    
exports["fromOscMessage with integer argument works"] = (test) ->
    oscaddr = osc.toOscString "/stuff"
    osctype = osc.toOscString ",i"
    oscarg = osc.toIntegerBuffer 888
    translate = osc.fromOscMessage osc.concatenateBuffers [oscaddr, osctype, oscarg]
    test.strictEqual translate?.address, "/stuff"
    test.strictEqual translate?.arguments?[0]?.type, "integer"
    test.strictEqual (translate?.arguments?[0]?.value), 888
    test.done()
    
exports["fromOscMessage with multiple arguments works."] = (test) ->
    oscaddr = osc.toOscString "/stuff"
    osctype = osc.toOscString ",sbi"
    oscargs = [
                (osc.toOscString "argu")
                (osc.concatenateBuffers [(osc.toIntegerBuffer 4), new Buffer "argu"])
                (osc.toIntegerBuffer 888)
    ]

    oscbuffer = osc.concatenateBuffers [oscaddr, osctype, (osc.concatenateBuffers oscargs)]
    translate = osc.fromOscMessage oscbuffer
    test.strictEqual translate?.address, "/stuff"
    test.strictEqual translate?.arguments?[0]?.type, "string"
    test.strictEqual (translate?.arguments?[0]?.value), "argu"
    test.done()

exports["fromOscMessage strict fails if type string has no comma"] = (test) ->
    oscaddr = osc.toOscString "/stuff"
    osctype = osc.toOscString "fake"
    translate = osc.fromOscMessage (osc.concatenateBuffers [oscaddr, osctype]), true
    test.strictEqual translate, null
    test.done()
    
exports["fromOscBundle works with no messages"] = (test) ->
    oscbundle = osc.toOscString "#bundle"
    osctimetag = osc.toIntegerBuffer 0, 8
    buffer = osc.concatenateBuffers [oscbundle, osctimetag]
    translate = osc.fromOscBundle buffer
    test.strictEqual translate?.timetag, 0
    test.deepEqual translate?.elements, []
    test.done()
    
exports["fromOscBundle works with single message"] = (test) ->
    oscbundle = osc.toOscString "#bundle"
    osctimetag = osc.toIntegerBuffer 0, 8
    oscaddr = osc.toOscString "/addr"
    osctype = osc.toOscString ","
    oscmessage = osc.concatenateBuffers [oscaddr, osctype]
    osclen = osc.toIntegerBuffer oscmessage.length
    buffer = osc.concatenateBuffers [oscbundle, osctimetag, osclen, oscmessage]
    translate = osc.fromOscBundle buffer
    test.strictEqual translate?.timetag, 0
    test.strictEqual translate?.elements?.length, 1
    test.strictEqual translate?.elements?[0]?.address, "/addr"
    test.done()
    
exports["fromOscBundle works with multiple messages"] = (test) ->
    oscbundle = osc.toOscString "#bundle"
    osctimetag = osc.toIntegerBuffer 0, 8
    oscaddr1 = osc.toOscString "/addr"
    osctype1 = osc.toOscString ","
    oscmessage1 = osc.concatenateBuffers [oscaddr1, osctype1]
    osclen1 = osc.toIntegerBuffer oscmessage1.length
    oscaddr2 = osc.toOscString "/addr2"
    osctype2 = osc.toOscString ","
    oscmessage2 = osc.concatenateBuffers [oscaddr2, osctype2]
    osclen2 = osc.toIntegerBuffer oscmessage2.length
    buffer = osc.concatenateBuffers [oscbundle, osctimetag, osclen1, oscmessage1, osclen2, oscmessage2]
    translate = osc.fromOscBundle buffer
    test.strictEqual translate?.timetag, 0
    test.strictEqual translate?.elements?.length, 2
    test.strictEqual translate?.elements?[0]?.address, "/addr"
    test.strictEqual translate?.elements?[1]?.address, "/addr2"
    test.done()
    
exports["fromOscBundle works with nested bundles"] = (test) ->
    oscbundle = osc.toOscString "#bundle"
    osctimetag = osc.toIntegerBuffer 0, 8
    oscaddr1 = osc.toOscString "/addr"
    osctype1 = osc.toOscString ","
    oscmessage1 = osc.concatenateBuffers [oscaddr1, osctype1]
    osclen1 = osc.toIntegerBuffer oscmessage1.length
    oscbundle2 = osc.toOscString "#bundle"
    osctimetag2 = osc.toIntegerBuffer 0, 8
    oscmessage2 = osc.concatenateBuffers [oscbundle2, osctimetag2]
    osclen2 = osc.toIntegerBuffer oscmessage2.length
    buffer = osc.concatenateBuffers [oscbundle, osctimetag, osclen1, oscmessage1, osclen2, oscmessage2]
    translate = osc.fromOscBundle buffer
    test.strictEqual translate?.timetag, 0
    test.strictEqual translate?.elements?.length, 2
    test.strictEqual translate?.elements?[0]?.address, "/addr"
    test.strictEqual translate?.elements?[1]?.timetag, 0
    test.done()
    
exports["fromOscBundle works with non-understood messages"] = (test) ->
    oscbundle = osc.toOscString "#bundle"
    osctimetag = osc.toIntegerBuffer 0, 8
    oscaddr1 = osc.toOscString "/addr"
    osctype1 = osc.toOscString ","
    oscmessage1 = osc.concatenateBuffers [oscaddr1, osctype1]
    osclen1 = osc.toIntegerBuffer oscmessage1.length
    oscaddr2 = osc.toOscString "/addr2"
    osctype2 = osc.toOscString ",α"
    oscmessage2 = osc.concatenateBuffers [oscaddr2, osctype2]
    osclen2 = osc.toIntegerBuffer oscmessage2.length
    buffer = osc.concatenateBuffers [oscbundle, osctimetag, osclen1, oscmessage1, osclen2, oscmessage2]
    translate = osc.fromOscBundle buffer
    test.strictEqual translate?.timetag, 0
    test.strictEqual translate?.elements?.length, 1
    test.strictEqual translate?.elements?[0]?.address, "/addr"
    test.done()
    
roundTripMessage = (args, test) ->
    oscMessage = {
        address : "/addr"
        arguments : args
    }
    roundTrip = osc.fromOscMessage (osc.toOscMessage oscMessage), true
    test.strictEqual roundTrip?.address, "/addr"
    test.strictEqual roundTrip?.arguments?.length, args.length
    for i in [0...args.length]
        comp = if args[i]?.value? then args[i].value else args[i]
        test.strictEqual roundTrip?.arguments?[i]?.type, args[i].type if args[i]?.type?
        if Buffer.isBuffer comp
            for j in [0...comp.length]
                test.strictEqual roundTrip?.arguments?[i]?.value?[j], comp[j] 
        else
            test.strictEqual roundTrip?.arguments?[i]?.value, comp
    
# we tested fromOsc* manually, so just use roundtrip testing for toOsc*
exports["toOscMessage with no arguments works"] = (test) ->
    roundTripMessage [], test
    test.done()

exports["toOscMessage with string argument works"] = (test) ->
    roundTripMessage ["strr"], test
    test.done()

exports["toOscMessage with bad layout works"] = (test) ->
    oscMessage = {
        address : "/addr"
        arguments : [
            "strr"
        ]
    }
    roundTrip = osc.fromOscMessage (osc.toOscMessage oscMessage), true
    test.strictEqual roundTrip?.address, "/addr"
    test.strictEqual roundTrip?.arguments?.length, 1
    test.strictEqual roundTrip?.arguments?[0]?.value, "strr"
    test.done()
    
exports["toOscMessage with integer argument works"] = (test) ->
    roundTripMessage [8], test
    test.done()
    
exports["toOscMessage with buffer argument works"] = (test) ->
    # buffer will have random contents, but that's okay.
    roundTripMessage [new Buffer 16], test
    test.done()
    
exports["toOscMessage with float argument works"] = (test) ->
    roundTripMessage [{value : (new Buffer 4), type : "float"}], test
    test.done()

exports["toOscMessage with multiple arguments works"] = (test) ->
    roundTripMessage ["str", 7, (new Buffer 30), {value : (new Buffer 4), type : "float"}], test
    test.done()
    
roundTripBundle = (elems, test) ->
    oscMessage = {
        timetag : 0
        elements : elems
    }
    roundTrip = osc.fromOscBundle (osc.toOscBundle oscMessage), true
    test.strictEqual roundTrip?.timetag, 0
    test.strictEqual roundTrip?.elements?.length, elems.length
    for i in [0...elems.length]
        test.strictEqual roundTrip?.elements?[i]?.timetag, elems[i].timetag
        test.strictEqual roundTrip?.elements?[i]?.address, elems[i].address
        
exports["toOscBundle with no elements works"] = (test) ->
    roundTripBundle [], test
    test.done()

exports["toOscBundle with one message works"] = (test) ->
    roundTripBundle [{address : "/addr"}], test
    test.done()
    
exports["toOscBundle with nested bundles works"] = (test) ->
    roundTripBundle [{address : "/addr"}, {timetag : 0}], test
    test.done()