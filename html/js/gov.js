function gov_document_ready()
{
    rb_make_editable();
    $("tr.oddeven:odd").addClass("odd");
    $("tr.oddeven:even").addClass("even");

    $( "#sort_blank, #sort_yay, #sort_nay" ).sortable({connectWith: ".gov_sortlist"}).disableSelection();
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

    $('td.abs').positionInsideTableCells();

    $('.gov_sortlist li').mouseover(alt_detail_queue);
    $('.gov_sortlist li').mouseout(alt_detail_dequeue);
    $('.gov-placement .alt').mouseover(alt_detail_queue);
    $('.gov-placement .alt').mouseout(alt_detail_dequeue);
    $('#alt-info .close').click(function(){
	$('#alt-info').animate({'opacity':0});
	return false;
    });

    log("ready");
}

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

    $('#alt-info .title').html('<a href="vote_alternative.tt?alt='+id+'">'+
			       alt.text()+'</a>');

    if(alt_detail[key])
    {
//	log('Has '+key);
	$('#alt-info .content').html(alt_detail[key]);
    }
    else
    {
//	log('Loading '+id);
	$.get("alt/?id="+id, function(data){
	    alt_detail[key]=data+" "; // No empty
	    $('#alt-info .content').html(data)
	});
    }

    info.position({
	of: alt,
	collision: 'none',
	using: function(pos){
	    if( info.css('opacity') == 1 )
	    {
		info.stop().animate({
		    top: pos['top'],
		});
	    }
	    else
	    {
		info.css('top',pos['top']);
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
