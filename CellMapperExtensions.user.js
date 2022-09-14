// ==UserScript==
// @name         CellMapper Extensions
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  Some stuff to make mapping towers faster and easier.
// @author       eicednefrerdushdne
// @match        https://www.cellmapper.net/map*
// @icon         https://www.google.com/s2/favicons?domain=cellmapper.net
// @grant        none
// ==/UserScript==

(function() {
    'use strict';
    select_interaction.getFeatures().on("add", function (e) {
        var marker = e.element; //the feature selected
        //console.log(e);
        //debugger;
        if(marker.get("base") != undefined) {
            var coordinates = marker.get('geometry').flatCoordinates;
            $.ajax({
                type: "GET",
                dataType: "json",
                url: "http://localhost:8080/enb/" + marker.get('MCC') + "/" + marker.get('MNC') + "/" + marker.get('name'),
                xhrFields: {
                    withCredentials: false
                },
                success :function(data)
                {
                    var minMaxZoom = data.length < 40 ? 30 : 16.5;

                    resetCircleLayer(map, 'circleLayer', Math.max(16.5, minMaxZoom), '#3399CCC0');
                    resetCircleLayer(map, 'circleLayer150', Math.max(18, minMaxZoom), '#ff9900C0');
                    resetCircleLayer(map, 'circleLayer0', Math.max(50, minMaxZoom),'#ff3300C0');
                    for(var key in data) {
                        var p = data[key];
                        if(p.TAMeters != -1) {
                            if(p.TAMeters == 0) {
                                p.TAMeters = 15;
                                addCircle(map, 'circleLayer0', [p.Longitude, p.Latitude], p.TAMeters);
                            } else if (p.TAMeters == 150) {
                                addCircle(map, 'circleLayer150', [p.Longitude, p.Latitude], p.TAMeters);
                            } else {
                                addCircle(map, 'circleLayer', [p.Longitude, p.Latitude], p.TAMeters);
                            }
                        }
                    }
                }
            });
        }
    });

    window.circleLayers = []


    var resetCircleLayer = function(map, layerName, maxZoom, color) {
        var view = map.getView();
        var projection = view.getProjection();

        if(window[layerName]) {
            window.circleLayers.splice(window.circleLayers.indexOf(window[layerName]), 1);
            map.removeLayer(window[layerName]);

        }

        // Source and vector layer
        var vectorSource = new ol.source.Vector({
            projection: projection.code_
        });

        window[layerName] = new ol.layer.Vector({
            source: vectorSource,
            style: new ol.style.Style({
                fill: new ol.style.Fill({
                    color: 'rgba(255,255,255,0.0)'
                }),
                stroke: new ol.style.Stroke({
                    color: color,
                    width: 1.25
                }),
                renderBuffer: 1000
            })
        });

        if(typeof maxZoom !== 'number') {
            maxZoom = 16.5;
        }
        window[layerName].setMaxZoom(maxZoom);

        map.addLayer(window[layerName]);
        window.circleLayers.push(window[layerName]);
    }

    var addCircle = function(map, layerName, coordinates, radius) {
        var view = map.getView();
        var projection = view.getProjection();
        var resolutionAtEquator = view.getResolution();
        var center = map.getView().getCenter();
        var pointResolution = projection.getPointResolutionFunc_(resolutionAtEquator, center);
        var resolutionFactor = resolutionAtEquator/pointResolution;
        radius = (radius / ol.proj.Units.METERS_PER_UNIT.m) * resolutionFactor;

        // Translate the Latitude and Longitude to projection coordinates

        coordinates = ol.proj.fromLonLat(coordinates, projection)

        var circle = new ol.geom.Circle(coordinates, radius);
        var circleFeature = new ol.Feature(circle);

        // Source and vector layer
        var vectorSource = window[layerName].getSource();
        vectorSource.addFeature(circleFeature);

    }

    var waitForTrue = function(testFunction, callback) {
        if (testFunction() === true) {
            callback();
        } else {
            setTimeout(function() {
                waitForTrue(testFunction, callback);
            }, 100);
        }
    };

    // Copies a string to the clipboard. Must be called from within an
    // event handler such as click. May return false if it failed, but
    // this is not always possible. Browser support for Chrome 43+,
    // Firefox 42+, Safari 10+, Edge and Internet Explorer 10+.
    // Internet Explorer: The clipboard feature may be disabled by
    // an administrator. By default a prompt is shown the first
    // time the clipboard is used (per session).
    window.copyToClipboard = function (text) {
        if (window.clipboardData && window.clipboardData.setData) {
            // Internet Explorer-specific code path to prevent textarea being shown while dialog is visible.
            return window.clipboardData.setData("Text", text);

        }
        else if (document.queryCommandSupported && document.queryCommandSupported("copy")) {
            var textarea = document.createElement("textarea");
            textarea.textContent = text;
            textarea.style.position = "fixed";  // Prevent scrolling to bottom of page in Microsoft Edge.
            document.body.appendChild(textarea);
            textarea.select();
            try {
                return document.execCommand("copy");  // Security exception may be thrown by some browsers.
            }
            catch (ex) {
                console.warn("Copy to clipboard failed.", ex);
                return false;
            }
            finally {
                document.body.removeChild(textarea);
            }
        }
    }

    window.openGoogleEarth = function(eNB){
        var t = window.Towers.find(function(z){return z.values_.name == eNB});

        // Translate the projection coordinates to Latitude and Longitude
        var coordinates = ol.proj.toLonLat(t.values_.geometry.flatCoordinates, map.getView().getProjection());

        $.ajax({
            type: "POST",
            url: "http://localhost:8080/openGoogleEarth",
            contentType: "application/json; charset=UTF-8",
            data: JSON.stringify({
                eNB: eNB,
                mcc: t.values_.MCC,
                mnc: t.values_.MNC,
                latitude: coordinates[1],
                longitude: coordinates[0],
                verified: t.values_.verified
            }),
            xhrFields: {
                withCredentials: false
            },
            success :function(data)
            {
            }
        });
    }

    window.setTowerMoverFilter = function() {

    }

    window.updateSmallCellState = function(isSmallCell, mcc, mnc, eNB) {
        if(isSmallCell) {
            window.smallcells.push('' + eNB);
        } else {
            var arrayIndex = window.smallcells.indexOf('' + eNB);
            if(arrayIndex !== -1) {
                window.smallcells.splice(arrayIndex, 1);
            }
        }

        $.ajax({
            type: isSmallCell ? "PUT" : "DELETE",
            dataType: "json",
            url: "http://localhost:8080/smallcells/" + mcc + "-" + mnc + "/" + eNB,
            xhrFields: {
                withCredentials: false
            },
            success :function(data)
            {
            }
        });
    };

    var improvegetNetworkInfo = function(map) {
        var func = window.getNetworkInfo;
        var functionContents = func.toString()
        functionContents = functionContents.substr(functionContents.indexOf('{') + 1, functionContents.lastIndexOf('}') - functionContents.indexOf('{') - 1)

        var insertText = `
        $.ajax({
            type: "GET",
            dataType: "json",
            url: "http://localhost:8080/smallcells/" + inMCC + "-" + inMNC,
            xhrFields: {
                withCredentials: false
            },
            success :function(data)
            {
                window.smallcells = data;
            }
        });

`
        var searchText = `		$.ajax({`
        var startIndex = functionContents.indexOf(searchText)

        var newContents = functionContents.substr(0, startIndex) + insertText + functionContents.substr(startIndex);

        var newfunc = new Function('inMCC', 'inMNC', newContents);
        window.getNetworkInfo = newfunc;
    }

    var improveContextMenu = function(map) {
        var listener = map.listeners_.contextmenu[0];
        var functionContents = listener.toString()
        functionContents = functionContents.substr(functionContents.indexOf('{') + 1, functionContents.lastIndexOf('}') - functionContents.indexOf('{') - 1)

        var insertText = `
                              + '<a href="javascript:copyToClipboard(\\'' + lat + ',' + long + '\\');">Copy Coordinates</a><br />'
                              + '<a href="http://www.antennasearch.com/HTML/search/search.php?address=' + lat +'%2C+' + long + '" target="_blank" rel="noreferrer">Open in AntennaSearch.com</a><br />'
`
        var searchText = 'var theHTML = \'\''
        var startIndex = functionContents.indexOf(searchText)

        var newContents = functionContents.substr(0, startIndex + searchText.length) + insertText + functionContents.substr(startIndex + searchText.length);

        newContents = newContents.replace(`'<a href="https://www.google.com/maps/@' + lat +',' + long + ',15z"`, `'<a href="https://www.google.com/maps/search/?api=1&query=' + lat +',' + long + '"`)
        var newListener = new Function('event', newContents);
        map.listeners_.contextmenu[0] = newListener;
    }

    var improveSideBarMenu = function(){
        var func = window.getBaseStation;
        var functionContents = func.toString()
        functionContents = functionContents.substr(functionContents.indexOf('{') + 1, functionContents.lastIndexOf('}') - functionContents.indexOf('{') - 1)

        var insertText = `
                var checkedText = window.smallcells.includes('' + inBase) ? 'checked' : '';
				output+= "<li><label style='margin-bottom: unset;'><input type='checkbox' " + checkedText + " onchange='updateSmallCellState(this.checked, " + inMCC + ", " + inMNC + ", " + inBase + "); ' style='display: inline-block;'> Is Small Cell</label></li>";
                output+= "<li><a href='#' onclick='openGoogleEarth(" + inBase + ")'>Open in Google Earth</a></li>";
`
        var searchText = `				output+= "<li><a href='#' onclick='HandleDeleteTower("`
        var startIndex = functionContents.indexOf(searchText)

        var newContents = functionContents.substr(0, startIndex) + insertText + functionContents.substr(startIndex);

        newContents = newContents.replace(`"<tr><td width='50%'>PCI</td><td>" +  towerData.cells[cellid].PCI + (systemType == "LTE" ? " (" + Math.floor(parseInt(towerData.cells[cellid].PCI)/3) + "/" + (parseInt(towerData.cells[cellid].PCI) % 3) + ")" : "") + "</td></tr>";`,
                                          `"<tr><td width='50%'>PCI</td><td><a href='#' onclick='$(\\"#pcipsc_search\\").val(\\"" + towerData.cells[cellid].PCI + "\\");handlePCIPSCSearch();'>" +  towerData.cells[cellid].PCI + (systemType == "LTE" ? " (" + Math.floor(parseInt(towerData.cells[cellid].PCI)/3) + "/" + (parseInt(towerData.cells[cellid].PCI) % 3) + ")" : "") + "</a></td></tr>";`);

        var newfunc = new Function('inMCC', 'inMNC', 'inLAC', 'inBase', 'inMarker', newContents);
        window.getBaseStation = newfunc;

    }

    window.togglingShowMineOnly = false;
    var fixtoggleshowMineOnly = function() {
        var func = window.toggleshowMineOnly;
        var functionContents = func.toString()

        functionContents = functionContents.substr(functionContents.indexOf('getTowersInView'), functionContents.lastIndexOf('}') - functionContents.indexOf('getTowersInView'))

        functionContents = `
        if(window.togglingShowMineOnly === true) {
          return;
        }
        var value = showMineOnly = !showMineOnly;
        ` + functionContents + `

        window.togglingShowMineOnly = true;
        $('#showMineOnly')[0].checked = showMineOnly;
        $('#showMineOnly2')[0].checked = showMineOnly;
        window.togglingShowMineOnly = false;
        `;

        var newfunc = new Function(functionContents);
        window.toggleshowMineOnly = newfunc;

    }

    window.togglingTrails = false;
    var fixToggleTrails = function() {
        var func = window.toggleTrails;
        var functionContents = func.toString()
        functionContents = functionContents.substr(functionContents.indexOf('{') + 1, functionContents.lastIndexOf('}') - functionContents.indexOf('{') - 1)

        functionContents = `
        if(window.togglingTrails === true) {
          return;
        }
        ` + functionContents + `

        window.togglingTrails = true;
        $('#doTrails')[0].checked = tilesEnabled;
        $('#doTrails2')[0].checked = tilesEnabled;
        window.togglingTrails = false;
        `;

        var newfunc = new Function(functionContents);
        window.toggleTrails = newfunc;

    }

    window.togglingShowUnverifiedOnly = false;
    var fixToggleShowUnverifiedOnly = function() {
        var func = window.toggleShowUnverifiedOnly;
        var functionContents = func.toString()
        functionContents = functionContents.substr(functionContents.indexOf('refreshTowers()'), functionContents.lastIndexOf('}') - functionContents.indexOf('refreshTowers()'))

        functionContents = `
        if(window.togglingShowUnverifiedOnly === true) {
          return;
        }

        window.togglingShowUnverifiedOnly = true;
        var value = window.showUnverifiedOnly = !window.showUnverifiedOnly;

        $('#showUnverifiedOnly')[0].checked = value;
        $('#showUnverifiedOnly2')[0].checked = value;
        window.togglingShowUnverifiedOnly = false;

        ` + functionContents;

        var newfunc = new Function(functionContents);
        window.toggleShowUnverifiedOnly = newfunc;

    }
    window.onlyPrimaryTowers = false;
    window.smallcells = [];
    window.filterTowerMover = [];
    window.excludeFilterTowerMover = false;
    var fixRefreshTowers = function() {
        var func = window.refreshTowers;
        var functionContents = func.toString()
        functionContents = functionContents.substr(functionContents.indexOf('{') + 1, functionContents.lastIndexOf('}') - functionContents.indexOf('{') - 1)

        var insertText = `
			if(filterTowerMover.length !== 0) {
                if(undefined === Towers[i].get("towerMover")) {
                    visible = false;
                } else if((filterTowerMover.indexOf(Towers[i].get("towerMover")) !== -1) === window.excludeFilterTowerMover) {
                    visible = false;
                }
            }

            if(typeof filterIDs !== 'undefined' && filterIDs.length !== 0 && filterIDs.indexOf(Towers[i].get('base')) === -1) {
                visible = false;
            }

            if(typeof window.smallcells !== 'undefined' && $('#filterSmallCells').length == 1) {
                 var filterValue = $('#filterSmallCells').val();
                 if(filterValue == 'HideSmallCells' && window.smallcells.indexOf(Towers[i].get('base')) !== -1)
                     visible = false;
                 else if(filterValue == 'OnlySmallCells' && window.smallcells.indexOf(Towers[i].get('base')) === -1)
                     visible = false;
            }

            if(window.onlyPrimaryTowers === true) {
                var bands = Towers[i].get('bands')
                if(!((bands.includes(12) || bands.includes(13)) && (bands.includes(2) || bands.includes(4) || bands.includes(66)))) {
                    visible = false;
                }
            }
`
        var searchText = `		/*	if(showMineOnly && userID != null)`
        var startIndex = functionContents.indexOf(searchText)

        var newContents = functionContents.substr(0, startIndex) + insertText + functionContents.substr(startIndex);

        var newfunc = new Function(newContents);
        window.refreshTowers = newfunc;
    }

    var fixHandleTowerMove = function() {
        var func = window.handleTowerMove;
        var functionContents = func.toString()
        functionContents = functionContents.substr(functionContents.indexOf('{') + 1, functionContents.lastIndexOf('}') - functionContents.indexOf('{') - 1)

        functionContents = functionContents.replace(`({delay:10000})`, `({delay:1000000, autohide: false})`)


        var newfunc = new Function('tower', 'latitude', 'longitude', functionContents);
        window.handleTowerMove = newfunc;
    }


    var fixPCISearch = function() {
        var func = window.handlePCIPSCSearch;
        var functionContents = func.toString()
        functionContents = functionContents.substr(functionContents.indexOf('{') + 1, functionContents.lastIndexOf('}') - functionContents.indexOf('{') - 1)

        var insertText = `
			window.filterIDs = [];
            $.each(towerData, function(i,item){
                filterIDs.push(item.siteID);
            });
            refreshTowers();
`
        var deleteStartText = `var displayData = "<b>R`
        var deleteEndText = `bootbox.alert(displayData);`

        var firstEndIndex = functionContents.indexOf(deleteStartText);
        var secondStartIndex = functionContents.indexOf(deleteEndText);

        var newContents = functionContents.substr(0, firstEndIndex) + insertText + functionContents.substr(secondStartIndex + deleteEndText.length);

        newContents = newContents.replace(`var theID = $("#pcipsc_search").val();`, `
        var theID = $("#pcipsc_search").val();
        if(theID === '') {
           window.filterIDs = [];
           refreshTowers();
           return;
        }`);

        var newfunc = new Function(newContents);
        window.handlePCIPSCSearch = newfunc;
    }

    window.toggleOnlyPrimaryTowers = function() {
        window.onlyPrimaryTowers = $('#onlyPrimaryTowers')[0].checked;
        refreshTowers();
    }

    // Modify the layer filter for the select interaction so it excludes the circle layers we've added.
    waitForTrue(function() {return map !== null && map.interactions.array_.some(el => {return el instanceof ol.interaction.Select})},
                function() {
        var interaction = map.interactions.array_.find(el => {return el instanceof ol.interaction.Select});
        interaction.layerFilter_ = function(l) {return !window.circleLayers.includes(l);};
    });


    waitForTrue(function() {return map !== null && map.listeners_ !== null  && map.listeners_.contextmenu !== null  && map.listeners_.contextmenu[0] !== null},
                function() {improveContextMenu(window.map);});

    waitForTrue(function() {return window.getNetworkInfo !== undefined},
                function() {improvegetNetworkInfo();});

    waitForTrue(function() {return window.getBaseStation !== undefined},
                function() {improveSideBarMenu();});

    waitForTrue(function() {return window.handleTowerMove !== undefined},
                function() {fixHandleTowerMove();});

    waitForTrue(function() {return window.handlePCIPSCSearch !== undefined},
                function() {fixPCISearch();});

    waitForTrue(function() {return window._renderUserStats !== undefined},
                function() {window._renderUserStats = function (inUid, divName)
    {
        $("#"+divName).append(" <a href='#' onclick='getUserHistory(" + inUid + ", 0)'><span title='" + ("Points: " + userCache[inUid].totalPoints + ", Cells: " + userCache[inUid].totalCells + ", Towers modified: " + userCache[inUid].totalLocatedTowers) + ", ID: " + inUid +"'>"  + userCache[inUid].userName + "</span>" + (userCache[inUid].premium ? "<span title='Premium User' style='color: gold'>&#x2605;</span></a>" : ""));
    };
                           });

    waitForTrue(function() {return window.toggleshowMineOnly !== undefined},
                function() {fixtoggleshowMineOnly();});

    waitForTrue(function() {return window.toggleTrails !== undefined},
                function() {fixToggleTrails();});

    waitForTrue(function() {return window.toggleShowUnverifiedOnly !== undefined},
                function() {fixToggleShowUnverifiedOnly();});

    waitForTrue(function() {return window.refreshTowers !== undefined},
                function() {fixRefreshTowers();});

    waitForTrue(function() {return $("#accountTable i.fa.caretIcon").length == 1},
                function() {
        $("#accountTable tr.collapsableSection").click();
    });

    waitForTrue(function() {return $("#tower_search").length == 1},
                function() {
        $("#towersearch tr.collapsedSection").click();
        $("#select_provider_table tr.collapsableSection").click();
        $("#filters tr.collapsedSection").click();
        $("#pcipscsearch tr.collapsedSection").click();

        $("#whatsnew").remove();
    });

    waitForTrue(function() {return $("#doLowAccuracy").length == 1},
                function() {
        $(`
        <tr><td width="50%">Small Cells</td>
        <td width="50%">
        <select onchange="refreshTowers();" id="filterSmallCells">
          <option value="AllTowers">All Towers</option>
          <option value="HideSmallCells" selected>Hide Small Cells</option>
          <option value="OnlySmallCells">Only Small Cells</option>
        </select>
        </td></tr>
        <tr>
			<td width="50%">Only Show Primary Towers</td>
			<td align="right"><input type="checkbox" id="onlyPrimaryTowers" onclick="toggleOnlyPrimaryTowers()"></td>
		</tr>
        `).insertBefore($('#doLowAccuracy').parents()[1]);
    });

    waitForTrue(function() {return $(".nav-link.nav-linkpage-scroll[href='https://cellmapper.freshdesk.com/']").length == 1},
                function() {
        var supportLink = $(".nav-link.nav-linkpage-scroll[href='https://cellmapper.freshdesk.com/']").parent();
        $(`
        <li class="nav-item">
          <label class="nav-link nav-linkpage-scroll">
            <input id="showMineOnly2" class="nav-logos fas" type="checkbox" onclick="toggleshowMineOnly()" />
            Show Mine Only
          </label>

        </li>

        <li class="nav-item">
          <label class="nav-link nav-linkpage-scroll">
            <input id="doTrails2" class="nav-logos fas" type="checkbox" onclick="toggleTrails()" />
            Signal Trails
          </label>

        </li>

        <li class="nav-item">
          <label class="nav-link nav-linkpage-scroll">
            <input id="showUnverifiedOnly2" class="nav-logos fas" type="checkbox" onclick="toggleShowUnverifiedOnly()" />
            Unverified Only
          </label>

        </li>

        <li class="nav-item">
          <label class="nav-link nav-linkpage-scroll" onclick="getTowersInView(MCC, MNC, true, netType)">
            <i class="nav-logos fas fa-redo"></i>
            Refresh Towers
          </label>

        </li>

        <li class="nav-item">
          <label class="nav-link nav-linkpage-scroll">
            Filter Tower Locator:
            <input type="text" id="locator_search" style="display: unset; font-size: 13.3333px; width: 83px; padding: 0px 3px; line-height: unset;" />
          </label>

        </li>
        `).insertAfter(supportLink);

        // I'm lazy: https://www.w3schools.com/howto/howto_js_trigger_button_enter.asp
        // Get the input field
        var input = document.getElementById("locator_search");

        // Execute a function when the user releases a key on the keyboard
        input.addEventListener("keyup", function(event) {
            // Number 13 is the "Enter" key on the keyboard
            if (event.keyCode === 13) {
                // Cancel the default action, if needed
                event.preventDefault();
                try {
                    var input = document.getElementById("locator_search").value;
                    if(input.startsWith('!')) {
                        window.excludeFilterTowerMover = true;
                        input = input.substring(1);
                    } else {
                        window.excludeFilterTowerMover = false;
                    }

                    input = input.split(',').filter(function(x,i){return x !== '';});;
                    filterTowerMover = []
                    for(var a in input) {
                        filterTowerMover.push(parseInt(input[a]))
                    }

                    // Trigger the button element with a click
                    refreshTowers();
                }catch {
                    // who cares
                }
            }
        });


        window.togglingShowUnverifiedOnly = window.togglingTrails = true;
        $("#doTrails2").prop('checked', tilesEnabled);
        $("#showUnverifiedOnly2").prop('checked', showUnverifiedOnly);
        window.togglingShowUnverifiedOnly = window.togglingTrails = false;
    });

function addGlobalStyle(css) {
    var head, style;
    head = document.getElementsByTagName('head')[0];
    if (!head) { return; }
    style = document.createElement('style');
    style.type = 'text/css';
    style.innerHTML = css.replace(/;/g, ' !important;');
    head.appendChild(style);
}
addGlobalStyle(`
@media (min-width: 576px) {
    .modal-dialog {
        max-width:800px;
    }
`);

})();
