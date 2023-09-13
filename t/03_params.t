use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Catalyst::Test 'MyApp03';
use HTTP::Request::Common;
use HTTP::Status;
use Test::More;

{
    my $req = GET('/');
    my ($res, $c) = ctx_request($req);
    is($res->code, RC_OK, 'response ok');
    is($res->content, 'index', 'content ok');
}
{
    my $req = POST('/', [foo => 'bar']);
    my ($res, $c) = ctx_request($req);
    is($res->code, RC_OK, 'response ok');
    is($c->req->param('foo'), 'bar', 'Normal POST body param, nothing to strip, left alone');
}
{
    my $req = POST('/', [foo => 'bar<script>alert("0");</script>']);
    my ($res, $c) = ctx_request($req);
    is($res->code, RC_OK, 'response ok');
    is($c->req->param('foo'), 'bar', 'XSS stripped from normal POST body param');
}
{
    # we allow <b> in the test app config so this should not be stripped
    my $req = POST('/', [foo => '<b>bar</b>']);
    my ($res, $c) = ctx_request($req);
    is($res->code, RC_OK, 'response ok');
    is($c->req->param('foo'), '<b>bar</b>', 'Allowed tag not stripped');
}
{
    diag "HTML left alone in ignored field - by regex match";
    my $value = '<h1>Bar</h1><p>Foo</p>';
    my $req = POST('/', [foo_html => $value]);
    my ($res, $c) = ctx_request($req);
    is($res->code, RC_OK, 'response ok');
    is(
        $c->req->param('foo_html'),
        $value,
        'HTML left alone in ignored (by regex) field',
    );
}
{
    diag "HTML left alone in ignored field - by name";
    my $value = '<h1>Bar</h1><p>Foo</p>';
    my $req = POST('/', [ignored_param => $value]);
    diag "*** REQ: $req";
    diag $req->as_string;
    my ($res, $c) = ctx_request($req);
    is($res->code, RC_OK, 'response ok');
    is(
        $c->req->param('ignored_param'),
        $value,
        'HTML left alone in ignored (by name) field',
    );
}

{
    # Test that data in a JSON body POSTed gets scrubbed too
    my $json_body = <<JSON;
{
    "foo": "Top-level <img src=foo.jpg title=fun>", 
    "baz":{
        "one":"Second-level <img src=test.jpg>"
    },
    "arr": [ 
        "one test <img src=arrtest1.jpg>",
        "two <script>window.alert('XSS!');</script>"
    ],
    "some_html": "Leave <b>this</b> alone: <img src=allowed.gif>"
}
JSON
    my $req = POST('/', 
        Content_Type => 'application/json', Content => $json_body
    );
    my ($res, $c) = ctx_request($req);
    is($res->code, RC_OK, 'response ok');
    is(
        $c->req->body_data->{foo}, 
        'Top-level ', # note trailing space where img was removed
        'Top level body param scrubbed',
    );
    is(
        $c->req->body_data->{baz}{one},
        'Second-level ',
        'Second level body param scrubbed',
    );
    is(
        $c->req->body_data->{arr}[0],
        'one test ',
        'Second level array contents scrubbbed',
    );
    is(
        $c->req->body_data->{some_html},
        'Leave <b>this</b> alone: <img src=allowed.gif>',
        'Body data param matching ignore_params left alone',
    );
}

done_testing();

