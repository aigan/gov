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
}

function saveSortable()
{
    document.forms["f"].run.value="place_vote";
    $("#vote").val( $.merge($.merge( $("#sort_yay").sortable("toArray"),["|"]),$("#sort_nay").sortable("toArray") ) );
}



jQuery(document).ready(gov_document_ready);
