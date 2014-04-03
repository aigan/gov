function gov_document_ready()
{
    $(window).load(gov_loaded);

    // Break out of frames
    if (top.location != location)
    {
	top.location.href = document.location.href ;
    }

    RDF.Base.makeEditable();
    $("tr.oddeven:odd").addClass("odd");
    $("tr.oddeven:even").addClass("even");

    $( "#sort_blank, #sort_yay, #sort_nay" ).sortable({
	start: on_sorting_start,
	stop: on_sorting_stop,
	connectWith: ".gov_sortlist",
	axis: "y"
    }).disableSelection();
    if( $('.gov_sortlist').length )
    {
	$("#f").submit( saveSortable );
    }

    $.fn.positionInsideTableCells = function()
    {
	var $el;
	return this.each(function() {
            $el = $(this);
            var newDiv = $("<div />", {
                "class": "innerWrapper",
                "css"  : {
                    "height"  : $el.height(),
                    "width"   : "100%",
                    "position": "relative"
                }
            });
            $el.wrapInner(newDiv);
	});
    };

    $('.gov_sortlist li').mouseover(alt_detail_queue);
    $('.gov_sortlist li').mouseout(alt_detail_dequeue);
    $('.gov-placement .alt').mouseover(alt_detail_queue);
    $('.gov-placement .alt').mouseout(alt_detail_dequeue);
    $('#alt-info .close').click(function(){
	$('#alt-info').animate({'opacity':0});
	return false;
    });

    $('.us-sortable').draggable({containment: "parent"});

    $('#alts-count').html($('.gov_sortlist li').length);
    $('#sorted-count').html($('#sort_yay li').length+$('#sort_nay li').length);

    log("ready");
}

function on_sorting_start( event, ui )
{
    log("Started sorting");
    if( $('#sort_yay li').length + $('#sort_nay li').length == 0 )
    {
	$('#sort_yay').effect("highlight","slow");
	$('#drop-here').css({left:"0",opacity: 0});
	$('#drop-here').animate({left:"+=50",opacity: 1});
    }
}

function on_sorting_stop( event, ui )
{
    log("Stopped sorting");
    var count = $('#sort_yay li').length+$('#sort_nay li').length;
    $('#sorted-count').html(count);
    $('#drop-here').css({left:"50"});
    $('#drop-here').animate({left:"+=150",opacity: 0});

    if( count == 0 )
	$('input[type=submit]').val($('#vote_blank').text());
    else
	$('input[type=submit]').val($('#place_vote').text());
}

function gov_loaded()
{
    log("gov_loaded");
    $('td.abs').positionInsideTableCells();
}


$(window).resize( function(){
    if( $(window).width() > 480 )
    {
	$('#menu-huvud_meny').removeAttr('style');
    }
});



var display_alt_timeout;
function alt_detail_queue(ev)
{
    display_alt_id = ev.target.id;
    if( display_alt_timeout )
	clearTimeout( display_alt_timeout );

    display_alt_timeout = setTimeout(function(){
	display_alt_detail(ev);
//	log("Display "+display_alt_id+"?");
    },300);
}

function alt_detail_dequeue()
{
    if( display_alt_timeout )
	clearTimeout( display_alt_timeout );
}

var alt_detail = new Array();
function display_alt_detail(ev)
{
    var alt=$(ev.target);
    var info = $('#alt-info');
    var key = alt[0].id;
    var id = key.substr(4); // Extract id from gov_123

    $('#alt-info .title').html('<a href="vote_alternative.tt?alt='+id+'" target="vote_alternative">'+
			       alt.text()+'</a>');

    if(alt_detail[key])
    {
//	log('Has '+key);
	$('#alt-info .content').html(alt_detail[key]);
    }
    else
    {
	$('#alt-info .content').empty();
	
//	log('Loading '+id);
	$.get("alt/?id="+id, function(data){
	    alt_detail[key]=data+" "; // No empty
	    $('#alt-info .content').html(data)
	});
    }

    // Position in viewport
    var left = $(window).width() - 470;
    if( left > 560 ) left = 560;
    log($(window).width());
    log(left);

    info.position({
	of: alt,
	collision: 'none',
	using: function(pos){
	    if( info.css('opacity') == 1 )
	    {
		info.stop().animate({
		    top: pos['top'],
		    left: left,
		});
	    }
	    else
	    {
		info.css({
		    'top': pos['top'],
		    'left': left,
		});
		info.animate( {'opacity':1} ); // fade in 
	    }
	},
    });
}

function saveSortable()
{
    document.forms["f"].run.value="place_vote";
    $("#vote").val( $.merge($.merge( $("#sort_yay").sortable("toArray"),["|"]),$("#sort_nay").sortable("toArray") ) );
}

function log(stuff)
{
    if( typeof console != 'undefined' )
    {
        console.log(stuff);
    }
}



jQuery(document).ready(gov_document_ready);
