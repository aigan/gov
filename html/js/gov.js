function gov_loaded()  // all parts completely loaded
{
    log("gov loaded");

    gov_context_aside_init();
    gov_menu_init(); /* no menu alterations after this */


//    log( parseFloat($("body").css("font-size"))*18 );

//    $('td.abs').positionInsideTableCells();
}

function gov_document_ready()
{
    $(window).load(gov_loaded); // all parts completely loaded

    // Break out of frames
    if (top.location != location)
    {
	    top.location.href = document.location.href ;
    }

//    RDF.Base.makeEditable();

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

/*
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
*/

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
    var count = $('#sort_yay li').length+$('#sort_nay li').length;
    $('#sorted-count').html(count);
    if( count == 0 )
	    $('#prop_submit').val($('#vote_blank').text());
    else
	    $('#prop_submit').val($('#place_vote').text());

 
    log("gov ready");
}

var $gov_context_aside_overlap = 0;
var $gov_context_aside_static = 0;
var $gov_context_aside_fullwidth_at = 500;
function gov_context_aside_init()
{
    log("gov_context_aside_init");

    /* Suppress animation during initial position */
    $('#wrapper').addClass('notransition');
    $('#context_aside').addClass('notransition');

    $('#context_menu').click(gov_context_aside_toggle);
    
    var $expand = $.totalStorage('#context_menu');
    if( $expand === null ) {
        if( $( document ).width() > 900 ) {
            $('#context_menu').addClass('expanded');
        }
    } else if( $( document ).width() < $gov_context_aside_fullwidth_at ) {
        // Don't expand context if it covers full width
    } else if( $expand == 1 ) {
        $('#context_menu').addClass('expanded');
    }

    $( window ).resize(function(){
        waitForFinalEvent(gov_context_aside_position, 150,'gov_context_aside');
    });


    gov_context_aside_position();

    setTimeout(function(){
        log("Turning animation back on");
        $('#wrapper').removeClass('notransition');
        $('#context_aside').removeClass('notransition');
    }, 0);
}

function gov_context_aside_toggle()
{
    if( $('#context_menu').hasClass('expanded') )
    {
        log('Hide context');
        $('#context_menu').removeClass('expanded');
        $.totalStorage('#context_menu',0);
    }
    else
    {
        log('Show context');
        $('#context_menu').addClass('expanded');
        $.totalStorage('#context_menu',1);
    }
    gov_context_aside_position();
}


function gov_context_aside_position()
{
    var $dw = $( document ).width();
    log('Position context_aside '+$dw);

    if(! $('#context_aside').html().length ) {
        $('#context_menu').removeClass('expanded');
        $('#context_menu').hide();
    } else {
    
        if( $dw < $gov_context_aside_fullwidth_at ) {
            $('#context_aside').css('width',$dw+'px');
            $('#context_aside').css('right',0);
        } else {
            $('#context_aside').width('');
        }

        if( $dw < 800 ) {
            $gov_context_aside_overlap = 1;
            $('#wrapper').css('padding-right',0);
        } else {
            $gov_context_aside_overlap = 0;
        }

        if( $dw > 1200 ) {
            $gov_context_aside_static = 1;
            $('#context_menu').addClass('expanded');
            $('#context_menu').hide();
        } else {
            $gov_context_aside_static = 0;
            $('#context_menu').show();
        }
    }

    var w = $('#context_aside').outerWidth();
    if( $('#context_menu').hasClass('expanded') )
    {
        $('#context_aside').css('right',0);
        if(! $gov_context_aside_overlap )
            $('#wrapper').css('padding-right',w);
    }
    else
    {
        $('#context_aside').css('right',-w);
        if(! $gov_context_aside_overlap )
            $('#wrapper').css('padding-right',0);
    }

    if( $('#context_aside').outerHeight() >  $('#content').height() )
        $('#content').height($('#context_aside').outerHeight());
}



var $gov_menu_copy;
var $gov_menu_folded_level = 0;
var $gov_menu_folded_width = 0;
var $gov_menu_width = 0;
function gov_menu_init()
{
    log("gov_menu_init");
    // TODO: use http://plugins.adchsm.me/slidebars/

    // Copy and populate from menu_row
    $gov_menu_copy = $('.menu_row').clone(1,1);
    $gov_menu_folded_width = $('.menu_row').width();

//    $( window ).resize(gov_menu_format);
    $( window ).resize(function(){
        waitForFinalEvent(gov_menu_format, 150,'gov_menu_format');
    });
    gov_menu_format();
}
function gov_menu_format()
{
    if( $('.menu_row').width() > $gov_menu_folded_width ) {
        gov_menu_redraw();
    }
    if( gov_menu_reorder() )
        pf_tree_toggle_init();
    gov_menu_update();
    
}
function gov_menu_redraw()
{
    log('REDRAW');
    $gov_menu_folded_width = $('.menu_row').width();
    $gov_menu_folded_level = 0;

    // Transiton some classes to the new menu
    $gov_menu_copy.find('#context_menu')
        .replaceWith($('#context_menu').clone(1,1));

    $('.menu_row').replaceWith($gov_menu_copy.clone(1,1));
    $gov_menu_width = 0;
}
function gov_menu_reorder()
{
    if( $gov_menu_width == 0 ) {
        $('.menu_row').children().each(function(){
            $gov_menu_width += $(this).width();
        });
        log("Menu width: "+$gov_menu_width);
    }

//    $y = $('#menu_primary').offset().top;
//    log("Menu at "+$y);
//    log("Containter width is "+$('.menu_row').width());
//    if( $y == 0 ) return;


    if( $('.menu_row').width() > $gov_menu_width ) return 0;
    if( $gov_menu_folded_level > 7 ) return 0;
    $gov_menu_folded_level ++;
    log("Folding level "+$gov_menu_folded_level);


    var $ul = $('#compact_menu>ul>li>ul');
    $('.menu_row >div>ul').each(function(){
        var $li = $(this).children('li');
        var $level = $li.attr('level');
        if( $level > 0 ) {
            if( $level > $gov_menu_folded_level ) return;
            $li.children('a').addClass('folding');
            $li.children('a').prepend('<i class="fa fa-caret-right fa-lg"></i>');
            $li.children('ul').css('display','block');
            $li.removeClass('toggle');
            $li.off('click.pf_toggle');

            $ul.prepend($li);

            $('#compact_menu').show();
        }
        $(this).remove();
    });

    $gov_menu_width = 0;
    gov_menu_reorder();

   return 1;
}
function gov_menu_update()
{
    gov_position_container();
    $gov_menu_folded_width = $('.menu_row').width();

    // Set width of dropdown menues
    $('.toggle').each(function(){
            $ul = $(this).children('ul');
        if( $(window).width() < $ul.width()*1.2 ){
            $ul.addClass('wide');
        } else if( $(this).offset().left +
                   parseFloat($ul.css('left')) < 0 ) {
            $ul.addClass('wide');
        } else {
            $ul.removeClass('wide');
        }
    });

}

function gov_position_container()
{
//    log("Reposition container");
    $('#container').css('margin-top',$('.menu_row').height());
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
    $('#drop-here').css({left:"50px"});
    $('#drop-here').animate({left:"+=150",opacity: 0});

    if( count == 0 )
	    $('#prop_submit').val($('#vote_blank').text());
    else
	    $('#prop_submit').val($('#place_vote').text());
}

/*
$(window).resize( function(){
    if( $(window).width() > 480 )
    {
	    $('#menu-huvud_meny').removeAttr('style');
    }
});
*/


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
